open Common_

type t = {
  debug: bool;
  url_traces: string;
  url_metrics: string;
  url_logs: string;
  headers: (string * string) list;
  batch_timeout_ms: int;
  bg_threads: int;
  ticker_thread: bool;
  ticker_interval_ms: int;
  self_trace: bool;
}

let pp out self =
  let pp_header ppf (a, b) = Format.fprintf ppf "@[%s: @,%s@]@." a b in
  let ppheaders = Format.pp_print_list pp_header in
  let {
    debug;
    url_traces;
    url_metrics;
    url_logs;
    headers;
    batch_timeout_ms;
    bg_threads;
    ticker_thread;
    ticker_interval_ms;
    self_trace;
  } =
    self
  in
  Format.fprintf out
    "{@[ debug=%B;@ url_traces=%S;@ url_metrics=%S;@ url_logs=%S;@ \
     headers=%a;@ batch_timeout_ms=%d; bg_threads=%d;@ ticker_thread=%B;@ \
     ticker_interval_ms=%d;@ self_trace=%B @]}"
    debug url_traces url_metrics url_logs ppheaders headers batch_timeout_ms
    bg_threads ticker_thread ticker_interval_ms self_trace

let make ?(debug = !debug_) ?url ?url_traces ?url_metrics ?url_logs
    ?(headers = get_headers ()) ?(batch_timeout_ms = 2_000) ?(bg_threads = 4)
    ?(ticker_thread = true) ?(ticker_interval_ms = 500) ?(self_trace = false) ()
    : t =
  let bg_threads = max 1 (min bg_threads 32) in

  let url_traces, url_metrics, url_logs =
    let base_url =
      match url with
      | None -> Option.value (get_url_from_env ()) ~default:default_url
      | Some url -> remove_trailing_slash url
    in
    let url_traces =
      match url_traces with
      | None ->
        Option.value
          (get_url_traces_from_env ())
          ~default:(base_url ^ "/v1/traces")
      | Some url -> url
    in
    let url_metrics =
      match url_metrics with
      | None ->
        Option.value
          (get_url_metrics_from_env ())
          ~default:(base_url ^ "/v1/metrics")
      | Some url -> url
    in
    let url_logs =
      match url_logs with
      | None ->
        Option.value (get_url_logs_from_env ()) ~default:(base_url ^ "/v1/logs")
      | Some url -> url
    in
    url_traces, url_metrics, url_logs
  in
  {
    debug;
    url_traces;
    url_metrics;
    url_logs;
    headers;
    batch_timeout_ms;
    bg_threads;
    ticker_thread;
    ticker_interval_ms;
    self_trace;
  }
