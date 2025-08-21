
#include <string.h>
#include <tree_sitter/api.h>
#include <emscripten/emscripten.h>


__attribute__((import_module("typst_env")))
extern void wasm_minimal_protocol_write_args_to_buffer(void *buf);
__attribute__((import_module("typst_env")))
extern void wasm_minimal_protocol_send_result_to_host(const void *buf, size_t len);


typedef struct {
  void *ptr;
  size_t len;
  size_t cap;
} Buffer;

size_t MIN_BUFFER_SIZE = 1024;

Buffer buffer_new() {
  Buffer buffer;
  buffer.ptr = malloc(MIN_BUFFER_SIZE);
  buffer.len = 0;
  buffer.cap = MIN_BUFFER_SIZE;
  return buffer;
}

void buffer_drop(Buffer buffer) {
  free(buffer.ptr);
}

void buffer_write(Buffer *buffer, const void *data, size_t len) {
  size_t new_len = buffer->len + len;
  if (new_len > buffer->cap) {
    size_t new_cap = buffer->cap << 1;
    while (new_cap < new_len) {
      new_cap <<= 1;
    }
    char *new_ptr = malloc(new_cap);
    memcpy(new_ptr, buffer->ptr, buffer->len);
    free(buffer->ptr);
    buffer->ptr = new_ptr;
    buffer->cap = new_cap;
  }

  memcpy(buffer->ptr + buffer->len, data, len);
  buffer->len = new_len;
}


int report_error(char *error) {
  wasm_minimal_protocol_send_result_to_host(error, strlen(error));
  return 1;
}


const TSLanguage *language;
TSParser *parser;
TSQuery *query;

const TSLanguage *typsitter_lang();
const char *typsitter_highlights();

EMSCRIPTEN_KEEPALIVE int typsitter_init() {
  language = typsitter_lang();
  const char *highlights = typsitter_highlights();

  parser = ts_parser_new();
  ts_parser_set_language(parser, language);

  TSQueryError query_error;
  uint32_t query_error_offset;
  query = ts_query_new(language, highlights, strlen(highlights), &query_error, &query_error_offset);

  if (query == NULL) {
    return report_error("error loading grammar");
  }

  return 0;
}

EMSCRIPTEN_KEEPALIVE int typsitter_highlight(size_t source_len) {

  char* source = malloc(source_len);
  wasm_minimal_protocol_write_args_to_buffer(source);

  TSTree *tree = ts_parser_parse_string(parser, NULL, source, source_len);
  TSNode root_node = ts_tree_root_node(tree);

  TSQueryCursor *cursor = ts_query_cursor_new();
  ts_query_cursor_exec(cursor, query, root_node);

  Buffer captures = buffer_new();

  TSQueryMatch match;
  uint32_t capture_index;
  while (ts_query_cursor_next_capture(cursor, &match, &capture_index)) {
    TSNode node = match.captures->node;
    uint32_t captures_index = match.captures->index;

    uint32_t capture_name_len;
    const char *capture_name = ts_query_capture_name_for_id(query, captures_index, &capture_name_len);

    uint32_t words[3] = {
      ts_node_start_byte(node),
      ts_node_end_byte(node),
      capture_name_len,
    };

    buffer_write(&captures, &words, 12);
    buffer_write(&captures, capture_name, capture_name_len);
  }

  wasm_minimal_protocol_send_result_to_host(captures.ptr, captures.len);
  buffer_drop(captures);

  ts_query_cursor_delete(cursor);
  ts_tree_delete(tree);

  free(source);

  return 0;
}
