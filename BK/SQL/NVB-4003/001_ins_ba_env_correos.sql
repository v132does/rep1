declare
  v_err        varchar2(4000);
  v_comentario varchar2(4000);
  v_parametros ba_env_correos.parametros%TYPE;
  cursor reg is
  select w.nro_correo,
         w.cod_persona,
         w.tip_producto,
         w.estado,
         w.fec_registro,
         w.fec_envio,
         w.msj_error,
         w.parametros,
         w.mai_destinatario 
   from ba_env_correos@uenodesg w
   where w.nro_correo not in (select p.nro_correo
                                from it.ba_env_correos p);
begin
  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  --desabilitar los triggers
  sql_util.ejecute_dml('alter table it.ba_env_correos disable all triggers',
                       v_err);
  if v_err is not null then
    v_comentario := 'Al desabilitar trigger TABLA IT.ba_env_correos' || v_err;
    dbms_output.put_line(v_comentario);
  end if;
    for w in reg loop
      v_parametros := w.parametros; 
      begin
      insert into it.ba_env_correos a
        (  a.nro_correo,
           a.cod_persona,
           a.tip_producto,
           a.estado,
           a.fec_registro,
           a.fec_envio,
           a.msj_error,
           a.parametros,
           a.usu_insercion,
           a.fec_insercion,
           a.usu_modificacion,
           a.fec_modificacion,
           a.mai_destinatario )
    values(w.nro_correo,
           w.cod_persona,
           w.tip_producto,
           w.estado,
           w.fec_registro,
           w.fec_envio,
           w.msj_error,
           v_parametros,
           'MIGRA',
           (sysdate),
           'MIGRA',
           (sysdate),
           w.mai_destinatario);
      commit;     
     exception 
       when others then
         dbms_output.put_line('Error al insertar '||sqlerrm);
      end;
  end loop;
  --habilitamos los triggers de ge_causales
  sql_util.ejecute_dml('alter table it.ba_env_correos enable all triggers',
                       v_err);
  if v_err is not null then
    v_comentario := 'Al habilitar trigger TABLA IT.ba_env_correos' || v_err;
    dbms_output.put_line(v_comentario);
  end if;
  ------
exception
  when others then
    raise_application_error(-20000,
                            'Error en el proceso de insercion: ' || '-' ||
                            sqlerrm);
end;
