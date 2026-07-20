/*
 * [INPUT]: Depends on the active UI locale, Fumadocs search hooks, static Orama indexes, and Mandarin tokenization.
 * [OUTPUT]: Provides a locale-filtered command-palette documentation search dialog.
 * [POS]: Serves as the browser-only adapter for prerendered search indexes.
 * [PROTOCOL]: Update this header when this file changes, then review AGENTS.md
 */
'use client';

import { create } from '@orama/orama';
import { createTokenizer } from '@orama/tokenizers/mandarin';
import { useDocsSearch } from 'fumadocs-core/search/client';
import { oramaStaticClient } from 'fumadocs-core/search/client/orama-static';
import {
  SearchDialog,
  SearchDialogClose,
  SearchDialogContent,
  SearchDialogHeader,
  SearchDialogIcon,
  SearchDialogInput,
  SearchDialogList,
  SearchDialogOverlay,
  type SharedProps,
} from 'fumadocs-ui/components/dialog/search';
import { useI18n } from 'fumadocs-ui/contexts/i18n';

function initOrama(locale?: string) {
  if (locale === 'zh-CN') {
    return create({
      schema: { _: 'string' },
      components: { tokenizer: createTokenizer() },
    });
  }

  return create({
    schema: { _: 'string' },
    language: 'english',
  });
}

export default function SkillsGoSearchDialog(props: SharedProps) {
  const { locale } = useI18n();
  const { search, setSearch, query } = useDocsSearch({
    client: oramaStaticClient({ initOrama, locale }),
  });

  return (
    <SearchDialog
      {...props}
      isLoading={query.isLoading}
      onSearchChange={setSearch}
      search={search}
    >
      <SearchDialogOverlay />
      <SearchDialogContent>
        <SearchDialogHeader>
          <SearchDialogIcon />
          <SearchDialogInput />
          <SearchDialogClose />
        </SearchDialogHeader>
        <SearchDialogList
          items={query.data !== 'empty' ? query.data : null}
        />
      </SearchDialogContent>
    </SearchDialog>
  );
}
