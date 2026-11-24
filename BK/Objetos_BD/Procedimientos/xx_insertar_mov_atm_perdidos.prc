create or replace procedure it.xx_insertar_mov_atm_perdidos is
 /*cursor c_datos is
 select *
   from it.xx_atm_perdidos_2 a;

 v_salida    varchar2(2000);*/
begin
  /*for x in c_datos loop
    dbms_lock.sleep(1);
    begin
      v_salida := fuj_pro_tra_atm(x.mensaje);

      ---Actualizar en la tabla ATM a regularizar
      begin
        update xx_atm_perdidos_2 b
           set b.respuesta = v_salida,
               b.fec_modificacion = sysdate,
               b.usu_modificacion = user
         where b.nro_orden = x.nro_orden;
      exception
        when others then
          raise_application_error(-20002, 'Error al actualizar tabla:'||sqlerrm);
      end;
    exception
      when others then
         raise_application_error(-20001, 'Error al procesar transaccion:'||sqlerrm);
    end;

  end loop;
  commit;
exception
  when others then
    raise_application_error(-20000,'Error al ejecutar:'||sqlerrm);*/
    null;
end;
/

