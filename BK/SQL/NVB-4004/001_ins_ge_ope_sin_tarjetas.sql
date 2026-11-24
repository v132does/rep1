DECLARE 
 v_err    VARCHAR2(4000);
 v_comentario  VARCHAR2(4000);


 Begin
   
   begin pre_ini_aplicacion; 
   pae_cnf.g_cod_modulo := 1; end;  
   
    --Desabilitar los triggers
    sql_util.ejecute_dml('alter table it.ge_ope_sin_tarjetas disable all triggers',v_err);
    IF v_err IS NOT NULL THEN
         v_comentario := 'Al desabilitar trigger TABLA IT.ge_ope_sin_tarjetas' || v_err;
          dbms_output.put_line(v_comentario);
    END IF;


insert into it.ge_ope_sin_tarjetas(cod_persona,
       nro_telefono,
       nro_cuenta,
       cod_moneda,
       fec_alta,
       estado,
       observacion,
       est_envio,
       usu_insercion,
       fec_insercion,
       usu_modificacion,
       fec_modificacion)
select a.cod_persona,
       a.nro_telefono,
       a.nro_cuenta,
       a.cod_moneda,
       a.fec_alta,
       a.estado,
       a.observacion,
       a.est_envio,
       'MIGRA',
       sysdate,
       'MIGRA',
       sysdate
from it.ge_ope_sin_tarjetas@uenodesg a;
/*WHERE not exists (select 1 from ge_pag_comercios c 
                  where c.nro_orden    = a.nro_orden
                  and   c.nro_factura  = a.nro_factura
                  and   c.cod_ente     = a.cod_ente);*/
commit;

    --Habilitamos los triggers 
      sql_util.ejecute_dml('alter table it.ge_ope_sin_tarjetas enable all triggers',v_err);
      IF v_err IS NOT NULL THEN
         v_comentario := 'Al habilitar trigger TABLA IT.ge_ope_sin_tarjetas' || v_err;
          dbms_output.put_line(v_comentario);
      END IF;
      
 ------
 exception
    when others then
            Raise_Application_error(-20000, 'Error en el proceso de insercion: ' ||'-'|| sqlerrm);
 end; 
   
