create or replace procedure it.prg_act_cod_mensaje(p_fec_extracto in date, p_fre_extracto in varchar2) is

cursor mensajes is
       select a.cod_mensaje, det_sql 
         from ge_msj_extractos b, ge_mensajes a
        where b.cod_mensaje = a.cod_mensaje
          and b.fec_extracto = p_fec_extracto
          and b.mensaje is not null
          and a.cod_mensaje <> '1'
         order by b.prioridad;
v_sentencia long;
v_error     varchar2(4000);
begin
  for msj in mensajes loop
      v_sentencia := 'update ge_ext_clientes set cod_mensaje = '||msj.cod_mensaje||
                   ' where cod_mensaje = 1 '||
                   '   and fec_extracto = to_date('''||to_char(p_fec_extracto,'ddmmyyyy')||''',''ddmmyyyy'')'||
                   '   and fre_extracto = '''||p_fre_extracto||''''||
                   '   and cod_persona in ('||msj.det_sql||')';
     sql_util.ejecute_dml(v_sentencia, v_error);
     if v_error is not null then
        raise_application_error(-20000,'Error en '||v_sentencia||'-'||v_error);
     else
        commit;
     end if;
  end loop;
end;
/

