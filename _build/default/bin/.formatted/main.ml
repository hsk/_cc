let () = print_endline "Hello, World!"

let () =
  let argc = Array.length Sys.argv in
  if argc != 2 then (
    Format.printf "Usage: ./mic [filename]\n";
    exit (-1))
  else
    let fname = Sys.argv.(1) in
    let inchan = open_in fname in
    let filebuf = Lexing.from_channel inchan in
    ignore (Mic.Parser.translation_unit Mic.Lexer.token filebuf);
    print_endline
      (Mic.Ast.show_programi
         (List.rev (List.mapi (fun i x -> (i, x)) (List.rev !Mic.Env.program))))
