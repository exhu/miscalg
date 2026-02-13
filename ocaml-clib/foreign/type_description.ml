open Ctypes

module Types (F : Ctypes.TYPE) = struct
  open F

  type myclib_ctx_t = unit ptr

  let myclib_ctx_t : myclib_ctx_t typ = ptr void
end
