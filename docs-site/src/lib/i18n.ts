/*
 * [INPUT]: Depends on Fumadocs i18n primitives, UI translation keys, and the Simplified Chinese language pack.
 * [OUTPUT]: Provides supported locales, localized UI translations, validation, and route helpers.
 * [POS]: Serves as the locale source of truth for docs-site content, routes, layouts, and search.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
import { zhCN } from '@fumadocs/language/zh-cn';
import { defineI18n } from 'fumadocs-core/i18n';
import { uiTranslations } from 'fumadocs-ui/i18n';

export const locales = ['en', 'zh-CN'] as const;
export type Locale = (typeof locales)[number];

export const defaultLocale: Locale = 'en';

export const i18n = defineI18n({
  defaultLanguage: defaultLocale,
  fallbackLanguage: null,
  hideLocale: 'never',
  languages: [...locales],
  parser: 'dot',
});

export const translations = i18n
  .translations()
  .extend(uiTranslations())
  .add({ en: { displayName: 'English' } })
  .preset('zh-CN', zhCN());

export function isLocale(value: string | undefined): value is Locale {
  return locales.some((locale) => locale === value);
}

export function resolveLocale(value: string | undefined): Locale {
  return isLocale(value) ? value : defaultLocale;
}
