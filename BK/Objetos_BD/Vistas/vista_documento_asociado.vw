create or replace force view it.vista_documento_asociado as
select de_id,
       itipdocaso,
       ddestipdocaso,
       dcdcderef,
       dntimdi,
       destdocaso,
       dpexpdocaso,
       dnumdocaso,
       itipodocaso,
       ddtipodocaso,
       to_char(t.dfecemidi, 'YYYY-MM-DD') as dfecemidi,
       dnumcomret,
       dnumrescf,
       itipcons,
       ddestipcons,
       dnumcons,
       dnumcontrol,
       drucfus
  from CB_DOC_ASOCIADO t
 order by 1;