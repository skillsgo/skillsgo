/*
 * [INPUT]: Depends on resolved SkillsGo semantic colors and Primer Primitives 11.9.0 component-state conventions.
 * [OUTPUT]: Provides source-traceable button, control, card, overlay, navigation, search, focus, and inverse-surface danger tokens as a Flutter ThemeExtension.
 * [POS]: Serves as the component-token layer between SkillsGo semantic colors and reusable Flutter widgets.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import 'package:flutter/material.dart';

@immutable
class SkillsComponentTokens extends ThemeExtension<SkillsComponentTokens> {
  const SkillsComponentTokens({
    required this.controlRest,
    required this.controlHover,
    required this.controlActive,
    required this.controlDisabled,
    required this.controlForeground,
    required this.controlForegroundDisabled,
    required this.controlBorder,
    required this.primaryRest,
    required this.primaryHover,
    required this.primaryForeground,
    required this.cardRest,
    required this.cardHover,
    required this.cardBorder,
    required this.overlay,
    required this.overlayBorder,
    required this.overlayBackdrop,
    required this.navigationRest,
    required this.navigationSelected,
    required this.navigationSelectedForeground,
    required this.searchRest,
    required this.searchActive,
    required this.focusRing,
    required this.statusAccent,
    required this.statusAccentContainer,
    required this.statusSuccess,
    required this.statusSuccessContainer,
    required this.statusAttention,
    required this.statusAttentionContainer,
    required this.statusSevere,
    required this.statusSevereContainer,
    required this.statusDanger,
    required this.statusDangerContainer,
    required this.statusDangerSolid,
    required this.statusDangerOnInverse,
    required this.statusDangerForeground,
    this.focusRingWidth = 2,
  });

  final Color controlRest;
  final Color controlHover;
  final Color controlActive;
  final Color controlDisabled;
  final Color controlForeground;
  final Color controlForegroundDisabled;
  final Color controlBorder;
  final Color primaryRest;
  final Color primaryHover;
  final Color primaryForeground;
  final Color cardRest;
  final Color cardHover;
  final Color cardBorder;
  final Color overlay;
  final Color overlayBorder;
  final Color overlayBackdrop;
  final Color navigationRest;
  final Color navigationSelected;
  final Color navigationSelectedForeground;
  final Color searchRest;
  final Color searchActive;
  final Color focusRing;
  final Color statusAccent;
  final Color statusAccentContainer;
  final Color statusSuccess;
  final Color statusSuccessContainer;
  final Color statusAttention;
  final Color statusAttentionContainer;
  final Color statusSevere;
  final Color statusSevereContainer;
  final Color statusDanger;
  final Color statusDangerContainer;
  final Color statusDangerSolid;
  final Color statusDangerOnInverse;
  final Color statusDangerForeground;
  final double focusRingWidth;

  @override
  SkillsComponentTokens copyWith({
    Color? controlRest,
    Color? controlHover,
    Color? controlActive,
    Color? controlDisabled,
    Color? controlForeground,
    Color? controlForegroundDisabled,
    Color? controlBorder,
    Color? primaryRest,
    Color? primaryHover,
    Color? primaryForeground,
    Color? cardRest,
    Color? cardHover,
    Color? cardBorder,
    Color? overlay,
    Color? overlayBorder,
    Color? overlayBackdrop,
    Color? navigationRest,
    Color? navigationSelected,
    Color? navigationSelectedForeground,
    Color? searchRest,
    Color? searchActive,
    Color? focusRing,
    Color? statusAccent,
    Color? statusAccentContainer,
    Color? statusSuccess,
    Color? statusSuccessContainer,
    Color? statusAttention,
    Color? statusAttentionContainer,
    Color? statusSevere,
    Color? statusSevereContainer,
    Color? statusDanger,
    Color? statusDangerContainer,
    Color? statusDangerSolid,
    Color? statusDangerOnInverse,
    Color? statusDangerForeground,
    double? focusRingWidth,
  }) => SkillsComponentTokens(
    controlRest: controlRest ?? this.controlRest,
    controlHover: controlHover ?? this.controlHover,
    controlActive: controlActive ?? this.controlActive,
    controlDisabled: controlDisabled ?? this.controlDisabled,
    controlForeground: controlForeground ?? this.controlForeground,
    controlForegroundDisabled:
        controlForegroundDisabled ?? this.controlForegroundDisabled,
    controlBorder: controlBorder ?? this.controlBorder,
    primaryRest: primaryRest ?? this.primaryRest,
    primaryHover: primaryHover ?? this.primaryHover,
    primaryForeground: primaryForeground ?? this.primaryForeground,
    cardRest: cardRest ?? this.cardRest,
    cardHover: cardHover ?? this.cardHover,
    cardBorder: cardBorder ?? this.cardBorder,
    overlay: overlay ?? this.overlay,
    overlayBorder: overlayBorder ?? this.overlayBorder,
    overlayBackdrop: overlayBackdrop ?? this.overlayBackdrop,
    navigationRest: navigationRest ?? this.navigationRest,
    navigationSelected: navigationSelected ?? this.navigationSelected,
    navigationSelectedForeground:
        navigationSelectedForeground ?? this.navigationSelectedForeground,
    searchRest: searchRest ?? this.searchRest,
    searchActive: searchActive ?? this.searchActive,
    focusRing: focusRing ?? this.focusRing,
    statusAccent: statusAccent ?? this.statusAccent,
    statusAccentContainer: statusAccentContainer ?? this.statusAccentContainer,
    statusSuccess: statusSuccess ?? this.statusSuccess,
    statusSuccessContainer:
        statusSuccessContainer ?? this.statusSuccessContainer,
    statusAttention: statusAttention ?? this.statusAttention,
    statusAttentionContainer:
        statusAttentionContainer ?? this.statusAttentionContainer,
    statusSevere: statusSevere ?? this.statusSevere,
    statusSevereContainer: statusSevereContainer ?? this.statusSevereContainer,
    statusDanger: statusDanger ?? this.statusDanger,
    statusDangerContainer: statusDangerContainer ?? this.statusDangerContainer,
    statusDangerSolid: statusDangerSolid ?? this.statusDangerSolid,
    statusDangerOnInverse: statusDangerOnInverse ?? this.statusDangerOnInverse,
    statusDangerForeground:
        statusDangerForeground ?? this.statusDangerForeground,
    focusRingWidth: focusRingWidth ?? this.focusRingWidth,
  );

  @override
  SkillsComponentTokens lerp(covariant SkillsComponentTokens? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return SkillsComponentTokens(
      controlRest: mix(controlRest, other.controlRest),
      controlHover: mix(controlHover, other.controlHover),
      controlActive: mix(controlActive, other.controlActive),
      controlDisabled: mix(controlDisabled, other.controlDisabled),
      controlForeground: mix(controlForeground, other.controlForeground),
      controlForegroundDisabled: mix(
        controlForegroundDisabled,
        other.controlForegroundDisabled,
      ),
      controlBorder: mix(controlBorder, other.controlBorder),
      primaryRest: mix(primaryRest, other.primaryRest),
      primaryHover: mix(primaryHover, other.primaryHover),
      primaryForeground: mix(primaryForeground, other.primaryForeground),
      cardRest: mix(cardRest, other.cardRest),
      cardHover: mix(cardHover, other.cardHover),
      cardBorder: mix(cardBorder, other.cardBorder),
      overlay: mix(overlay, other.overlay),
      overlayBorder: mix(overlayBorder, other.overlayBorder),
      overlayBackdrop: mix(overlayBackdrop, other.overlayBackdrop),
      navigationRest: mix(navigationRest, other.navigationRest),
      navigationSelected: mix(navigationSelected, other.navigationSelected),
      navigationSelectedForeground: mix(
        navigationSelectedForeground,
        other.navigationSelectedForeground,
      ),
      searchRest: mix(searchRest, other.searchRest),
      searchActive: mix(searchActive, other.searchActive),
      focusRing: mix(focusRing, other.focusRing),
      statusAccent: mix(statusAccent, other.statusAccent),
      statusAccentContainer: mix(
        statusAccentContainer,
        other.statusAccentContainer,
      ),
      statusSuccess: mix(statusSuccess, other.statusSuccess),
      statusSuccessContainer: mix(
        statusSuccessContainer,
        other.statusSuccessContainer,
      ),
      statusAttention: mix(statusAttention, other.statusAttention),
      statusAttentionContainer: mix(
        statusAttentionContainer,
        other.statusAttentionContainer,
      ),
      statusSevere: mix(statusSevere, other.statusSevere),
      statusSevereContainer: mix(
        statusSevereContainer,
        other.statusSevereContainer,
      ),
      statusDanger: mix(statusDanger, other.statusDanger),
      statusDangerContainer: mix(
        statusDangerContainer,
        other.statusDangerContainer,
      ),
      statusDangerSolid: mix(statusDangerSolid, other.statusDangerSolid),
      statusDangerOnInverse: mix(
        statusDangerOnInverse,
        other.statusDangerOnInverse,
      ),
      statusDangerForeground: mix(
        statusDangerForeground,
        other.statusDangerForeground,
      ),
      focusRingWidth:
          focusRingWidth + (other.focusRingWidth - focusRingWidth) * t,
    );
  }
}

extension SkillsComponentTheme on BuildContext {
  SkillsComponentTokens get skillsComponents =>
      Theme.of(this).extension<SkillsComponentTokens>()!;
}
