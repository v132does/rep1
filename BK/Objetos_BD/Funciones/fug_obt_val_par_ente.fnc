CREATE OR REPLACE FUNCTION IT.FUG_OBT_VAL_PAR_ENTE( P_PAR_ENTE      IN GE_PAR_ENTES.PARAMETRO%TYPE,
                                                 P_PARAMETRO     IN GE_PAR_ENTES.PARAMETRO%TYPE,
                                                 P_VAL_PARAMETRO IN GE_PAR_ENTES.VAL_PARAMETRO%TYPE
                                               ) RETURN VARCHAR2
IS
  /*
  || Busca el valor de un parámetro de ente (p_par_ente), a partir de otro parámetro (p_parametro)
  || y su correspondiente valor (p_val_parametro) para el mismo ente.
  */
  v_val_parametro ge_par_entes.val_parametro%type;
BEGIN
   select pe.val_parametro
     into v_val_parametro
     from ge_par_entes pe
    where pe.parametro  = p_par_ente
      and exists (select 0
                    from ge_par_entes p
                   where p.parametro   = p_parametro
                     and val_parametro = p_val_parametro
                     and p.cod_ente    = pe.cod_ente
                 );
   return v_val_parametro;
EXCEPTION
  when no_data_found then
     RETURN null;
  when others then
    raise_application_error(-20000, 'Error en FUG_OBT_VAL_PAR_ENTE '||sqlerrm);
END FUG_OBT_VAL_PAR_ENTE;
/

