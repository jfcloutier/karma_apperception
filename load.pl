:- prolog_load_context(directory, Dir),
   string_concat(Dir, '/code', Code),
   asserta(user:file_search_path(apperception, Code)),
   string_concat(Dir, '/../karma_prolog_utils/code', Utils),
   asserta(user:file_search_path(utils, Utils)),
   string_concat(Dir, '/tests', Tests),
   asserta(user:file_search_path(tests, Tests)).
