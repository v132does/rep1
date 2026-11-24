CREATE OR REPLACE PROCEDURE IT.PRG_ACT_PAR_ENTES
 (P_COD_ENTE IN GE_ENTES.COD_ENTE%TYPE
 ,P_CAMPO IN GE_PAR_ENTES.PARAMETRO%TYPE,
 P_VALOR IN VARCHAR2
 )
 IS
v_fila varchar2(200);
BEGIN
   begin pre_ini_aplicacion;pae_cnf.g_cod_modulo:=1;end;
   select rowid
     into v_fila
     from ge_par_entes
    where cod_ente = p_cod_ente
     and parametro = p_campo
      for update of val_parametro nowait;
   update ge_par_entes
      set val_parametro = p_valor
    where rowid = v_fila;
   exception
      when no_data_found then
        insert into ge_par_entes
           (cod_ente, parametro, val_parametro)
        values
           (p_cod_ente, p_campo, p_valor);

      when others then
        raise_application_error(-20000,
        'Error en el Parametro '||p_campo||' p/Ente  '||p_cod_ente||'-'||sqlerrm );
END;
/

