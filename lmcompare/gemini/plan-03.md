# Phase 03: Simple HTTP Router (`src/urouter.pas`)

## Objective

Implement `src/urouter.pas` providing a simple method-and-path HTTP router with path normalization, fallback handler support, and `405 Method Not Allowed` / `404 Not Found` handling.

## Coding Rules

- Must begin with `unit urouter;` and `{$mode objfpc}{$H+}`.
- Strictly 2-space indentation, zero tab characters (`\t`).
- Strictly under 1000 lines.

## Step-by-Step Instructions

1. **Create `src/urouter.pas`** using `SysUtils, httpdefs, uhttpfiles`.

2. **Define types and class in `interface`**:
   - `TRouteHandler = procedure(ARequest: TRequest; AResponse: TResponse) of object;`
   - `TRouteEntry = record`
     - `Method: string;`
     - `Path: string;`
     - `Handler: TRouteHandler;`
     - `end;`
   - `THttpRouter = class(TObject)` with:
     - `private` fields:
       - `FRoutes: array of TRouteEntry;`
       - `FFallbackHandler: TRouteHandler;`
     - `public` methods:
       - `class function NormalizePath(const APath: string): string;`
         - **Critical FPC 3.2.2 behavior**: `TFPHttpServer` sets `ARequest.PathInfo := ''` for requests to `'/'`.
         - `NormalizePath` MUST trim whitespace, map `''` to `'/'`, prepend `'/'` if missing, and strip trailing `'/'` when `Length(Result) > 1`.
       - `procedure AddRoute(const AMethod, APath: string; AHandler: TRouteHandler);`
         - Stores `UpperCase(Trim(AMethod))` (supporting `'*'` as wildcard), `NormalizePath(APath)`, and `AHandler`.
       - `procedure SetFallbackHandler(AHandler: TRouteHandler);`
       - `procedure Dispatch(ARequest: TRequest; AResponse: TResponse);`
         1. Compute `ReqPath := NormalizePath(ARequest.PathInfo);`
         2. Compute `ReqMethod := UpperCase(Trim(ARequest.Method));`
         3. Iterate `FRoutes`:
            - If `FRoutes[I].Path = ReqPath` then:
              - Set `PathMatched := True;`
              - If `(FRoutes[I].Method = '*') or (FRoutes[I].Method = ReqMethod)` then invoke `FRoutes[I].Handler(ARequest, AResponse)` and `Exit`.
         4. If `PathMatched` is `True`: call `SendErrorResponse(AResponse, 405, '405 Method Not Allowed');` and `Exit`.
         5. Otherwise, if `Assigned(FFallbackHandler)` call `FFallbackHandler(ARequest, AResponse)`, else call `SendErrorResponse(AResponse, 404, '404 Not Found');`.

3. **Verify compilation and style**:
   - Run `fpc -Mobjfpc -Sh -FUbuild -Fusrc src/urouter.pas`
   - Run `wc -l src/urouter.pas` (must be `< 1000`) and `! grep -P '\t' src/urouter.pas` (must have zero tabs).
