/*
 * [INPUT]: Depends on Flutter Material theming, flutter_svg, and vendored Agent logo assets.
 * [OUTPUT]: Provides the shared theme-aware AgentLogo widget, canonical Agent ID-to-asset mappings, optional dark variants, and a text fallback.
 * [POS]: Serves as the single Agent identity visual used by installation and Library navigation surfaces.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AgentLogo extends StatelessWidget {
  const AgentLogo({
    super.key,
    required this.agentId,
    required this.displayName,
    this.size = 18,
  });

  final String agentId;
  final String displayName;
  final double size;

  static String? assetPathFor(String agentId) => switch (agentId
      .toLowerCase()) {
    'codex' => 'assets/agent-logos/codex.svg',
    'claude' || 'claude-code' => 'assets/agent-logos/claude-code.svg',
    'opencode' => 'assets/agent-logos/opencode.svg',
    'github-copilot' => 'assets/agent-logos/github-copilot.svg',
    'cursor' => 'assets/agent-logos/cursor.svg',
    'gemini-cli' => 'assets/agent-logos/gemini-cli.svg',
    'cline' => 'assets/agent-logos/cline.svg',
    'kiro-cli' => 'assets/agent-logos/kiro.svg',
    'trae' || 'trae-cn' => 'assets/agent-logos/trae.svg',
    'warp' => 'assets/agent-logos/warp.svg',
    'windsurf' => 'assets/agent-logos/windsurf.svg',
    'workbuddy' => 'assets/agent-logos/workbuddy.svg',
    'zed' => 'assets/agent-logos/zed.svg',
    'openclaw' => 'assets/agent-logos/openclaw.svg',
    'amp' => 'assets/agent-logos/amp.svg',
    'antigravity' || 'antigravity-cli' => 'assets/agent-logos/antigravity.svg',
    'astrbot' => 'assets/agent-logos/astrbot.svg',
    'autohand-code' => 'assets/agent-logos/autohand-code.svg',
    'augment' => 'assets/agent-logos/augment.svg',
    'bob' => 'assets/agent-logos/ibm-bob.svg',
    'codearts-agent' => 'assets/agent-logos/huawei-cloud.svg',
    'codebuddy' => 'assets/agent-logos/codebuddy.svg',
    'command-code' => 'assets/agent-logos/command-code.svg',
    'continue' => 'assets/agent-logos/continue.svg',
    'cortex' => 'assets/agent-logos/cortex-code.svg',
    'deepagents' => 'assets/agent-logos/deep-agents.svg',
    'devin' => 'assets/agent-logos/devin.svg',
    'dexto' => 'assets/agent-logos/dexto.svg',
    'droid' => 'assets/agent-logos/droid.svg',
    'firebender' => 'assets/agent-logos/firebender.svg',
    'forgecode' => 'assets/agent-logos/forgecode.svg',
    'goose' => 'assets/agent-logos/goose.svg',
    'hermes-agent' => 'assets/agent-logos/hermes-agent.svg',
    'iflow-cli' => 'assets/agent-logos/iflow-cli.svg',
    'inference-sh' => 'assets/agent-logos/inference-sh.svg',
    'junie' => 'assets/agent-logos/junie.svg',
    'kilo' => 'assets/agent-logos/kilo-code.svg',
    'kimi-code-cli' => 'assets/agent-logos/kimi-code.svg',
    'lingma' => 'assets/agent-logos/alibaba-cloud.svg',
    'mistral-vibe' => 'assets/agent-logos/mistral-vibe.svg',
    'mcpjam' => 'assets/agent-logos/mcpjam.svg',
    'mux' => 'assets/agent-logos/mux.svg',
    'ona' => 'assets/agent-logos/ona.svg',
    'openhands' => 'assets/agent-logos/openhands.svg',
    'pi' => 'assets/agent-logos/pi.svg',
    'pochi' => 'assets/agent-logos/pochi.svg',
    'promptscript' => 'assets/agent-logos/promptscript.svg',
    'qoder' || 'qoder-cn' => 'assets/agent-logos/qoder.svg',
    'qwen-code' => 'assets/agent-logos/qwen-code.svg',
    'reasonix' => 'assets/agent-logos/reasonix.svg',
    'replit' => 'assets/agent-logos/replit.svg',
    'rovodev' => 'assets/agent-logos/rovo.svg',
    'roo' => 'assets/agent-logos/roo-code.svg',
    'tabnine-cli' => 'assets/agent-logos/tabnine.svg',
    'adal' => 'assets/agent-logos/adal.svg',
    'zcode' => 'assets/agent-logos/zcode.svg',
    'zencoder' || 'zenflow' => 'assets/agent-logos/zencoder.svg',
    _ => null,
  };

  static String? darkAssetPathFor(String agentId) =>
      switch (agentId.toLowerCase()) {
        'opencode' => 'assets/agent-logos/opencode-dark.svg',
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final basePath = assetPathFor(agentId);
    final path = Theme.of(context).brightness == Brightness.dark
        ? darkAssetPathFor(agentId) ?? basePath
        : basePath;
    if (path != null) {
      return SizedBox.square(
        dimension: size,
        child: SvgPicture.asset(path, fit: BoxFit.contain),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(size * .28),
        ),
        child: Center(
          child: Text(
            displayName.characters.firstOrNull?.toUpperCase() ?? '?',
            style: TextStyle(
              color: scheme.onSecondaryContainer,
              fontSize: size * .56,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
