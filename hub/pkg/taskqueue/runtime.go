/*
 * [INPUT]: Depends on typed River JobArgs, registered Hub job handlers, workload queue assignments, pgx transactions, process-local timers, and River's PostgreSQL runtime.
 * [OUTPUT]: Provides type-safe registration, per-job timeout overrides, bounded workload-isolated queue allocation, terminal finalization, active-job reconciliation lookup, synchronous execution, burst-mode durable PostgreSQL scheduling, and transactional enqueue.
 * [POS]: Serves as the Hub infrastructure boundary for observable, retryable, multi-instance-safe background jobs without resident idle polling.
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
	IdleTimeout          time.Duration
}

const (
	QueueSource        = "source"
	QueueMaintenance   = "maintenance"
	defaultIdleTimeout = 30 * time.Second
	stopTimeout        = 30 * time.Second
)

// BalancedQueueWorkers partitions one total worker budget so network-heavy
// source work cannot starve small maintenance and coordination jobs.
func BalancedQueueWorkers(total int) map[string]int {
	if total < 3 {
		return map[string]int{river.QueueDefault: total}
	}
	maintenance := 1
	defaultWorkers := max(1, total*2/5)
	source := total - maintenance - defaultWorkers
	return map[string]int{
		river.QueueDefault: defaultWorkers,
		QueueSource:        source,
		QueueMaintenance:   maintenance,
	}
}

// Runtime dispatches typed jobs either synchronously or through River.
type Runtime struct {
	handlers      map[string]func(context.Context, river.JobArgs) error
	failures      map[string]func(context.Context, river.JobArgs, error) error
	workers       *river.Workers
	river         *river.Client[pgx.Tx]
	mu            sync.Mutex
	started       bool
	periodic      []periodicJob
	controlCancel context.CancelFunc
	wake          chan struct{}
	idleTimeout   time.Duration
	riverMu       sync.Mutex
	riverRunning  bool
	wg            sync.WaitGroup
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

type jobArgsWithTimeout interface {
	JobTimeout() time.Duration
}

func (w *typedWorker[T]) Timeout(job *river.Job[T]) time.Duration {
	if args, ok := any(job.Args).(jobArgsWithTimeout); ok {
		return args.JobTimeout()
	}
	return 0
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
	return &Runtime{handlers: make(map[string]func(context.Context, river.JobArgs) error), failures: make(map[string]func(context.Context, river.JobArgs, error) error), workers: river.NewWorkers(), wake: make(chan struct{}, 1), idleTimeout: defaultIdleTimeout}
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
	idleTimeout := runtimeOptions.IdleTimeout
	if idleTimeout <= 0 {
		idleTimeout = defaultIdleTimeout
	}
	return &Runtime{handlers: make(map[string]func(context.Context, river.JobArgs) error), failures: make(map[string]func(context.Context, river.JobArgs, error) error), workers: workers, river: client, wake: make(chan struct{}, 1), idleTimeout: idleTimeout}, nil
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

// Start begins process-local scheduling. Durable River workers start only when
// queued work is due and stop again after the queue becomes idle.
func (r *Runtime) Start(ctx context.Context) error {
	r.mu.Lock()
	if r.started {
		r.mu.Unlock()
		return nil
	}
	controlCtx, cancel := context.WithCancel(ctx)
	r.controlCancel = cancel
	r.started = true
	periodic := append([]periodicJob(nil), r.periodic...)
	r.mu.Unlock()

	if r.river != nil {
		r.wg.Add(1)
		go r.runBurstController(controlCtx)
	}
	for _, spec := range periodic {
		r.wg.Add(1)
		go r.runPeriodic(controlCtx, spec)
	}
	if r.river != nil {
		r.Wake()
	}
	return nil
}

// Stop gracefully stops durable job processing and waits for local handlers.
func (r *Runtime) Stop(ctx context.Context) error {
	r.mu.Lock()
	if !r.started {
		r.mu.Unlock()
		return nil
	}
	r.started = false
	cancel := r.controlCancel
	r.controlCancel = nil
	r.mu.Unlock()
	if cancel != nil {
		cancel()
	}
	if err := r.stopRiver(ctx); err != nil {
		return err
	}
	done := make(chan struct{})
	go func() {
		r.wg.Wait()
		close(done)
	}()
	select {
	case <-done:
		return nil
	case <-ctx.Done():
		return ctx.Err()
	}
}

// Every registers one process-local timer that submits a durable River job only
// when its interval elapses. Waiting timers never access PostgreSQL.
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
	if err == nil {
		r.Wake()
	}
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
	if err == nil {
		// PostgreSQL delivers River's transactional NOTIFY only after commit. An
		// early wake is safe on rollback and ensures the worker is already ready
		// when a successful commit becomes visible.
		r.Wake()
	}
	return err
}

// Wake requests durable work without blocking request or transaction paths.
func (r *Runtime) Wake() {
	if r.river == nil {
		return
	}
	select {
	case r.wake <- struct{}{}:
	default:
	}
}

func (r *Runtime) runBurstController(ctx context.Context) {
	defer r.wg.Done()
	var scheduled <-chan time.Time
	for {
		select {
		case <-ctx.Done():
			return
		case <-r.wake:
		case <-scheduled:
		}
		scheduled = nil
		if err := r.startRiver(); err != nil {
			scheduled = time.After(r.idleTimeout)
			continue
		}

		idle := time.NewTimer(r.idleTimeout)
		for {
			select {
			case <-ctx.Done():
				idle.Stop()
				return
			case <-r.wake:
				resetTimer(idle, r.idleTimeout)
			case <-idle.C:
				active, next, err := r.inspectWork(ctx, time.Now())
				if err != nil || active {
					resetTimer(idle, r.idleTimeout)
					continue
				}
				stopCtx, cancel := context.WithTimeout(context.Background(), stopTimeout)
				err = r.stopRiver(stopCtx)
				cancel()
				if err != nil {
					resetTimer(idle, r.idleTimeout)
					continue
				}
				if next != nil {
					delay := time.Until(*next)
					if delay < 0 {
						delay = 0
					}
					scheduled = time.After(delay)
				}
				idle.Stop()
				goto waiting
			}
		}
	waiting:
	}
}

func (r *Runtime) startRiver() error {
	r.riverMu.Lock()
	defer r.riverMu.Unlock()
	if r.river == nil || r.riverRunning {
		return nil
	}
	if err := r.river.Start(context.Background()); err != nil {
		return fmt.Errorf("start River client: %w", err)
	}
	r.riverRunning = true
	return nil
}

func (r *Runtime) stopRiver(ctx context.Context) error {
	r.riverMu.Lock()
	defer r.riverMu.Unlock()
	if r.river == nil || !r.riverRunning {
		return nil
	}
	if err := r.river.Stop(ctx); err != nil {
		return fmt.Errorf("stop River client: %w", err)
	}
	r.riverRunning = false
	return nil
}

// inspectWork distinguishes immediately executable work from future retry or
// scheduled work so the resident River services can stop between due times.
func (r *Runtime) inspectWork(ctx context.Context, now time.Time) (bool, *time.Time, error) {
	immediate, err := r.river.JobList(ctx, river.NewJobListParams().States(
		rivertype.JobStateAvailable, rivertype.JobStatePending, rivertype.JobStateRunning,
	).First(1))
	if err != nil {
		return false, nil, err
	}
	future, err := r.river.JobList(ctx, river.NewJobListParams().States(
		rivertype.JobStateRetryable, rivertype.JobStateScheduled,
	).OrderBy(river.JobListOrderByScheduledAt, river.SortOrderAsc).First(1))
	if err != nil {
		return false, nil, err
	}
	return workSchedule(now, immediate.Jobs, future.Jobs)
}

func workSchedule(now time.Time, immediate, future []*rivertype.JobRow) (bool, *time.Time, error) {
	if len(immediate) > 0 {
		return true, nil, nil
	}
	if len(future) == 0 {
		return false, nil, nil
	}
	next := future[0].ScheduledAt
	return !next.After(now), &next, nil
}

func (r *Runtime) isRiverRunning() bool {
	r.riverMu.Lock()
	defer r.riverMu.Unlock()
	return r.riverRunning
}

func resetTimer(timer *time.Timer, delay time.Duration) {
	if !timer.Stop() {
		select {
		case <-timer.C:
		default:
		}
	}
	timer.Reset(delay)
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
		insertOpts.UniqueOpts = river.UniqueOpts{
			ByArgs: true,
			ByState: []rivertype.JobState{
				rivertype.JobStateAvailable,
				rivertype.JobStatePending,
				rivertype.JobStateRetryable,
				rivertype.JobStateRunning,
				rivertype.JobStateScheduled,
			},
		}
	}
	return insertOpts
}
