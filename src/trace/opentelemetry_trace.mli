module Otel := Opentelemetry
module Otrace := Trace
module TLS := Ambient_context_tls.Thread_local

(** [ocaml-opentelemetry.trace] implements a {!Trace_core.Collector} for {{:https://v3.ocaml.org/p/trace} ocaml-trace}.

    After installing this collector with {!setup}, you can consume libraries
    that use ocaml-trace, and they will automatically emit OpenTelemetry spans
    and logs.

    Both explicit scope (in the [_manual] functions such as [enter_manual_span])
    and implicit scope (in {!Internal.M.with_span}, via {!Ambient_context}) are
    supported; see the detailed notes on {!Internal.M.enter_manual_span}. *)

val setup : unit -> unit
(** Install the OTEL backend as a Trace collector *)

val setup_with_otel_backend : Opentelemetry.Collector.backend -> unit
(** Same as {!setup},  but also install the given backend as OTEL backend *)

val collector : unit -> Trace.collector
(** Make a Trace collector that uses the OTEL backend to send spans and logs *)

(** Internal implementation details; do not consider these stable. *)
module Internal : sig
  module M : sig
    val with_span :
      __FUNCTION__:string option ->
      __FILE__:string ->
      __LINE__:int ->
      data:(string * Otrace.user_data) list ->
      string (* span name *) ->
      (Otrace.span -> 'a) ->
      'a
    (** Implements {!Trace_core.Collector.S.with_span}, with the OpenTelemetry
        collector as the backend. Invoked via {!Trace.with_span}.

        Notably, this has the same implicit-scope semantics as
        {!Opentelemetry.Trace.with_}, and requires configuration of
        {!Ambient_context}.

      @see <https://github.com/ELLIOTTCABLE/ocaml-ambient-context> ambient-context docs *)

    val enter_manual_span :
      parent:Otrace.explicit_span option ->
      flavor:'a ->
      __FUNCTION__:string option ->
      __FILE__:string ->
      __LINE__:int ->
      data:(string * Otrace.user_data) list ->
      string (* span name *) ->
      Otrace.explicit_span
    (** Implements {!Trace_core.Collector.S.enter_manual_span}, with the OpenTelemetry
        collector as the backend. Invoked at {!Trace.enter_manual_toplevel_span}
        and {!Trace.enter_manual_sub_span}; requires an eventual call to
        {!Trace.exit_manual_span}.

        These 'manual span' functions {e do not} implement the same implicit-
        scope semantics of {!with_span}; and thus don't need to wrap a single
        stack-frame / callback; you can freely enter a span at any point, store
        the returned {!Trace.explicit_span}, and exit it at any later point with
        {!Trace.exit_manual_span}.

        However, for that same reason, they also cannot update the
        {!Ambient_context} — that is, when you invoke the various [manual]
        functions, if you then invoke other functions that use
        {!Trace.with_span}, those callees {e will not} see the span you entered
        manually as their [parent].

        Generally, the best practice is to only use these [manual] functions at
        the 'leaves' of your callstack: that is, don't invoke user callbacks
        from within them; or if you do, make sure to pass the [explicit_span]
        you recieve from this function onwards to the user callback, so they can create further
        child-spans. *)

    val exit_manual_span : Otrace.explicit_span -> unit
    (** Implements {!Trace_core.Collector.S.exit_manual_span}, with the
        OpenTelemetry collector as the backend. Invoked at
        {!Trace.exit_manual_span}. Expects the [explicit_span] returned from an
        earlier call to {!Trace.enter_manual_toplevel_span} or
        {!Trace.enter_manual_sub_span}.

        (See the notes at {!enter_manual_span} about {!Ambient_context}.) *)

    val message :
      ?span:Otrace.span ->
      data:(string * Otrace.user_data) list ->
      string ->
      unit

    val shutdown : unit -> unit

    val name_process : string -> unit

    val name_thread : string -> unit

    val counter_int : string -> int -> unit

    val counter_float : string -> float -> unit
  end

  type span_begin = {
    id: Otel.Span_id.t;
    start_time: int64;
    name: string;
    data: (string * Otrace.user_data) list;
    __FILE__: string;
    __LINE__: int;
    __FUNCTION__: string option;
    trace_id: Otel.Trace_id.t;
    scope: Otel.Scope.t;
    parent_id: Otel.Span_id.t option;
    parent_scope: Otel.Scope.t option;
  }

  module Active_span_tbl : Hashtbl.S with type key = Otrace.span

  (** Table indexed by ocaml-trace spans. *)
  module Active_spans : sig
    type t = private { tbl: span_begin Active_span_tbl.t } [@@unboxed]

    val create : unit -> t

    val tls : t TLS.t

    val get : unit -> t
  end

  val otrace_of_otel : Otel.Span_id.t -> Otrace.span

  val otel_of_otrace : Otrace.span -> Otel.Span_id.t

  val spankind_of_string : string -> Otel.Span.kind

  val otel_attrs_of_otrace_data :
    (string * Otrace.user_data) list ->
    Otel.Span.kind * Otel.Span.key_value list

  val enter_span' :
    ?explicit_parent:Otrace.span ->
    __FUNCTION__:string option ->
    __FILE__:string ->
    __LINE__:int ->
    data:(string * Otrace.user_data) list ->
    string ->
    Otrace.span * span_begin

  val exit_span' : Otrace.span -> span_begin -> Otel.Span.t
end
