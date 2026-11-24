create or replace procedure it.PRJ_ALT_SAL_PROSEGUR is
  v_nro_operacion number := 1;
  v_msj_respuesta varchar2(100);

 /* cursor cur_sal is
  select * from xx_saldos_prosegur;*/

  /*
  create table xx_saldos_prosegur(cod_transaccion number,nro_documento number,cod_moneda varchar2(3),
  monto number,nro_cuenta varchar2(20),concepto varchar2(100),nombre_cliente varchar2(200))
  */
begin
 /* for x in cur_sal loop
    dbms_lock.sleep(1);

    if(x.cod_transaccion=106) then
      v_msj_respuesta := fuj_pro_transaccion_106(v_nro_operacion,909,x.nro_documento,x.cod_moneda,x.monto,x.nro_cuenta,x.concepto);

      if v_msj_respuesta NOT LIKE '%~000~%' THEN
        raise_application_error(-20000,'Error al procesar transacción 106 en PRJ_ALT_SAL_PROSEGUR. '||v_msj_respuesta||'. '||sqlerrm);
      end if;

      v_nro_operacion := v_nro_operacion+1;

    elsif(x.cod_transaccion=107) then
      v_msj_respuesta := fuj_pro_transaccion_107(v_nro_operacion,909,x.nro_documento,x.cod_moneda,x.monto,x.nro_cuenta,x.concepto);

      if v_msj_respuesta NOT LIKE '%~000~%' THEN
        raise_application_error(-20000,'Error al procesar transacción 107 en PRJ_ALT_SAL_PROSEGUR. '||v_msj_respuesta||'. '||sqlerrm);
      end if;

      v_nro_operacion := v_nro_operacion+1;

    end if;
  end loop;
  commit;*/
  null;
end PRJ_ALT_SAL_PROSEGUR;
/

