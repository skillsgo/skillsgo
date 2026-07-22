/*
 * [INPUT]: Depends on typed River JobArgs, registered Hub job handlers, workload queue assignments, pgx transactions, and River's PostgreSQL runtime.
 * [OUTPUT]: Provides type-safe registration, bounded workload-isolated queue allocation, terminal finalization, active-job reconciliation lookup, synchronous execution, durable PostgreSQL enqueue/scheduling, and transactional enqueue.
 * [POS]: Serves as the Hub infrastructure boundary for observable, retryable, multi-instance-safe background jobs.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
package taskqueue

import (
	"context"
	"encoding/json"
	"fmt"
	"reflect"
	"sync"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/riverqueue/river"
	"github.com/riverqueue/river/riverdriver/riverpgxv5"
	"github.com/riverqueue/river/rivermigrate"
	"github.com/riverqueue/river/rivertype"
)

// Handler executes one concrete River job type. Implementations must be idempotent.
type Handler[T river.JobArgs] func(context.Context, T) error
type FailureHandler[T river.JobArgs] func(context.Context, T, error) error

// InsertOptions controls retry and active-job uniqueness.
type InsertOptions struct {
	Unique      bool
	MaxAttempts int
	Queue       string
}

// RiverOptions controls failure detection for durable workers. Zero values use
// River production defaults.
type RiverOptions struct {
	JobTimeout           time.Duration
	RescueStuckJobsAfter time.Duration
	QueueWorkers         map[string]int
}

const (
	QueueSource      = "source"
	QueueMaintenance = "maintenance"
)

// BalancedQueueWorkers partitions one total worker budget so network-heavy
// source work cannot starve small maintenance and coordination jobs.
func BalancedQueueWorkers(total int) map[string]int {
	if total < 3 {
		return map[string]int{river.QueueDefault: total}
	}
	maintenance := max(1, total/5)
	defaultWorkers := max(1, total/5)
	source := total - maintenance - defaultWorkers
	return map[string]int{
		river.QueueDefault: defaultWorkers,
		QueueSource:        source,
		QueueMaintenance:   maintenance,
	}
}

// Runtime dispatches typed jobs either synchronously or through River.
type Runtime struct {
	handlers map[string]func(context.Context, river.JobArgs) error
	failures map[string]func(context.Context, river.JobArgs, error) error
	workers  *river.Workers
	river    *river.Client[pgx.Tx]
	mu       sync.Mutex
	started  bool
	periodic []periodicJob
	cancel   context.CancelFunc
	wg       sync.WaitGroup
}

type periodicJob struct {
	args       river.JobArgs
	opts       InsertOptions
	interval   time.Duration
	runOnStart bool
}

type typedWorker[T river.JobArgs] struct {
	river.WorkerDefaults[T]
	handler Handler[T]
	runtime *Runtime
	kind    string
}

func (w *typedWorker[T]) Work(ctx context.Context, job *river.Job[T]) (err error) {
	defer func() {
		if recovered := recover(); recovered != nil {
			if job.Attempt >= job.MaxAttempts {
				w.finalize(ctx, job.Args, fmt.Errorf("job panicked"))
			}
			panic(recovered)
		}
	}()
	err = w.handler(ctx, job.Args)
	if err != nil && job.Attempt >= job.MaxAttempts {
		w.finalize(ctx, job.Args, err)
	}
	return err
}

func (w *typedWorker[T]) finalize(ctx context.Context, args T, cause error) {
	finalizeCtx, cancel := context.WithTimeout(context.WithoutCancel(ctx), 30*time.Second)
	defer cancel()
	_ = w.runtime.finalizeFailure(finalizeCtx, w.kind, args, cause)
}

// NewSynchronous creates the deterministic local/test substitute.
func NewSynchronous() *Runtime {
	return &Runtime{handlers: make(map[string]func(context.Context, river.JobArgs) error), failures: make(map[string]func(context.Context, river.JobArgs, error) error), workers: river.NewWorkers()}
}

// NewRiver migrates River's schema and creates a runtime sharing Catalog's
// pgx pool. Typed workers must be registered before Start.
func NewRiver(ctx context.Context, pool *pgxpool.Pool, maxWorkers int, options ...RiverOptions) (*Runtime, error) {
	if pool == nil {
		return nil, fmt.Errorf("PostgreSQL pool is required")
	}
	if maxWorkers < 1 {
		return nil, fmt.Errorf("max workers must be at least 1")
	}
	driver := riverpgxv5.New(pool)
	migrator, err := rivermigrate.New(driver, nil)
	if err != nil {
		return nil, fmt.Errorf("create River migrator: %w", err)
	}
	if _, err := migrator.Migrate(ctx, rivermigrate.DirectionUp, nil); err != nil {
		return nil, fmt.Errorf("migrate River schema: %w", err)
	}
	workers := river.NewWorkers()
	var runtimeOptions RiverOptions
	if len(options) > 0 {
		runtimeOptions = options[0]
	}
	queues := runtimeOptions.QueueWorkers
	if len(queues) == 0 {
		queues = map[string]int{river.QueueDefault: maxWorkers}
	}
	riverQueues := make(map[string]river.QueueConfig, len(queues))
	for queue, workers := range queues {
		if workers < 1 {
			return nil, fmt.Errorf("queue %q workers must be at least 1", queue)
		}
		riverQueues[queue] = river.QueueConfig{MaxWorkers: workers}
	}
	client, err := river.NewClient(driver, &river.Config{
		JobTimeout:           runtimeOptions.JobTimeout,
		Queues:               riverQueues,
		RescueStuckJobsAfter: runtimeOptions.RescueStuckJobsAfter,
		Workers:              workers,
	})
	if err != nil {
		return nil, fmt.Errorf("create River client: %w", err)
	}
	return &Runtime{handlers: make(map[string]func(context.Context, river.JobArgs) error), failures: make(map[string]func(context.Context, river.JobArgs, error) error), workers: workers, river: client}, nil
}

// Register installs one typed worker during service assembly.
func Register[T river.JobArgs](runtime *Runtime, handler Handler[T]) error {
	runtime.mu.Lock()
	defer runtime.mu.Unlock()
	if runtime.started {
		return fmt.Errorf("cannot register job handler after runtime start")
	}
	if handler == nil {
		return fmt.Errorf("job handler is required")
	}
	var zero T
	kind := zero.Kind()
	if kind == "" {
		return fmt.Errorf("job kind is required")
	}
	if _, exists := runtime.handlers[kind]; exists {
		return fmt.Errorf("job handler %q is already registered", kind)
	}
	runtime.handlers[kind] = func(ctx context.Context, args river.JobArgs) error {
		typed, ok := args.(T)
		if !ok {
			return fmt.Errorf("job %q received args %T", kind, args)
		}
		return handler(ctx, typed)
	}
	river.AddWorker(runtime.workers, &typedWorker[T]{handler: handler, runtime: runtime, kind: kind})
	return nil
}

// RegisterFailureHandler installs a business finalizer invoked synchronously
// when River is executing the last permitted attempt for one job kind.
func RegisterFailureHandler[T river.JobArgs](runtime *Runtime, handler FailureHandler[T]) error {
	runtime.mu.Lock()
	defer runtime.mu.Unlock()
	if runtime.started {
		return fmt.Errorf("cannot register failure handler after runtime start")
	}
	if handler == nil {
		return fmt.Errorf("failure handler is required")
	}
	var zero T
	kind := zero.Kind()
	if _, registered := runtime.handlers[kind]; !registered {
		return fmt.Errorf("job handler %q must be registered before its failure handler", kind)
	}
	if _, exists := runtime.failures[kind]; exists {
		return fmt.Errorf("failure handler %q is already registered", kind)
	}
	runtime.failures[kind] = func(ctx context.Context, args river.JobArgs, err error) error {
		typed, ok := args.(T)
		if !ok {
			return fmt.Errorf("failure handler %q received args %T", kind, args)
		}
		return handler(ctx, typed, err)
	}
	return nil
}

func (r *Runtime) finalizeFailure(ctx context.Context, kind string, args river.JobArgs, cause error) error {
	finalizer := r.failures[kind]
	if finalizer == nil {
		return nil
	}
	return finalizer(ctx, args, cause)
}

// Start begins durable job processing or the local periodic substitute.
func (r *Runtime) Start(ctx context.Context) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.started {
		return nil
	}
	if r.river != nil {
		if err := r.river.Start(ctx); err != nil {
			return fmt.Errorf("start River client: %w", err)
		}
	}
	if r.river == nil && len(r.periodic) > 0 {
		periodicCtx, cancel := context.WithCancel(ctx)
		r.cancel = cancel
		for _, spec := range r.periodic {
			r.wg.Add(1)
			go r.runPeriodic(periodicCtx, spec)
		}
	}
	r.started = true
	return nil
}

// Stop gracefully stops durable job processing and waits for local handlers.
func (r *Runtime) Stop(ctx context.Context) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if !r.started {
		return nil
	}
	r.started = false
	if r.cancel != nil {
		r.cancel()
		r.cancel = nil
	}
	if r.river != nil {
		if err := r.river.Stop(ctx); err != nil {
			return fmt.Errorf("stop River client: %w", err)
		}
	}
	r.wg.Wait()
	return nil
}

// Every registers one typed durable River periodic job or its local substitute.
func (r *Runtime) Every(args river.JobArgs, opts InsertOptions, interval time.Duration, runOnStart bool) error {
	r.mu.Lock()
	defer r.mu.Unlock()
	if r.started {
		return fmt.Errorf("cannot register periodic job after runtime start")
	}
	if interval <= 0 {
		return fmt.Errorf("periodic job interval must be positive")
	}
	if err := r.validate(args); err != nil {
		return err
	}
	insertOpts := riverInsertOptions(opts)
	if r.river != nil {
		r.river.PeriodicJobs().Add(river.NewPeriodicJob(
			river.PeriodicInterval(interval),
			func() (river.JobArgs, *river.InsertOpts) { return args, insertOpts },
			&river.PeriodicJobOpts{RunOnStart: runOnStart},
		))
		return nil
	}
	r.periodic = append(r.periodic, periodicJob{args: args, opts: opts, interval: interval, runOnStart: runOnStart})
	return nil
}

func (r *Runtime) runPeriodic(ctx context.Context, spec periodicJob) {
	defer r.wg.Done()
	if spec.runOnStart {
		_ = r.Enqueue(ctx, spec.args, spec.opts)
	}
	ticker := time.NewTicker(spec.interval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			_ = r.Enqueue(ctx, spec.args, spec.opts)
		}
	}
}

// Enqueue submits a typed job outside a domain transaction.
func (r *Runtime) Enqueue(ctx context.Context, args river.JobArgs, opts InsertOptions) error {
	if err := r.validate(args); err != nil {
		return err
	}
	if r.river == nil {
		return r.handlers[args.Kind()](ctx, args)
	}
	_, err := r.river.Insert(ctx, args, riverInsertOptions(opts))
	return err
}

// EnqueueTx atomically submits a typed River job with PostgreSQL domain changes.
func (r *Runtime) EnqueueTx(ctx context.Context, tx pgx.Tx, args river.JobArgs, opts InsertOptions) error {
	if err := r.validate(args); err != nil {
		return err
	}
	if r.river == nil {
		return r.handlers[args.Kind()](ctx, args)
	}
	if tx == nil {
		return fmt.Errorf("PostgreSQL transaction is required")
	}
	_, err := r.river.InsertTx(ctx, tx, args, riverInsertOptions(opts))
	return err
}

func (r *Runtime) validate(args river.JobArgs) error {
	if args == nil || args.Kind() == "" {
		return fmt.Errorf("job args and kind are required")
	}
	if _, ok := r.handlers[args.Kind()]; !ok {
		return fmt.Errorf("job handler %q is not registered", args.Kind())
	}
	return nil
}

// HasActiveJob reports whether the durable queue still owns a non-terminal job
// with the exact typed arguments. Domain reconcilers use it only to distinguish
// healthy queued work from orphaned business state.
func HasActiveJob[T river.JobArgs](ctx context.Context, runtime *Runtime, args T) (bool, error) {
	if runtime.river == nil {
		return false, nil
	}
	result, err := runtime.river.JobList(ctx, river.NewJobListParams().Kinds(args.Kind()).States(
		rivertype.JobStateAvailable, rivertype.JobStatePending, rivertype.JobStateRetryable,
		rivertype.JobStateRunning, rivertype.JobStateScheduled,
	).First(10_000))
	if err != nil {
		return false, err
	}
	for _, job := range result.Jobs {
		var candidate T
		if err := json.Unmarshal(job.EncodedArgs, &candidate); err != nil {
			return false, err
		}
		if reflect.DeepEqual(candidate, args) {
			return true, nil
		}
	}
	return false, nil
}

func riverInsertOptions(opts InsertOptions) *river.InsertOpts {
	insertOpts := &river.InsertOpts{MaxAttempts: opts.MaxAttempts, Queue: opts.Queue}
	if opts.Unique {
		insertOpts.UniqueOpts = river.UniqueOpts{ByArgs: true}
	}
	return insertOpts
}
