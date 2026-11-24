CREATE OR REPLACE PROCEDURE IT."PRB_TRA_ASI_MASIVA" is
   --- Transferencia masiva de asientos desde un archivo temporal
   v_fec_sistema date := sysdate;
   v_error varchar2(2000);
   v_cod_tip_asiento ge_transacciones.cod_tip_asiento%type;
   cursor asientos is
   select cod_modalidad modalidad, cod_tra_hijo transaccion, cod_tip_asiento asiento, cod_tip_asiento2 asiento2,
       null tasa, decode(interoficina,'Si','1',2) oficina,
       decode(cod_moneda,'Guaranies','GS','Dolares','USD','Euros','EUR','OTRO') cod_moneda, cod_rubro rub_contable,
       decode(cod_sec_credito,'No Financ./No Publ','N','Publico','P','Financiero','F','No Importa', null, 'No importa',null,'Finan.Public.','I', 'I') cod_sector,
       tip_movimiento movimiento, decode(residente,'Residente','S','No importa', 'X','No Importa','X', 'N') residente,
       decode(plazo,'Importa','S','N') plazo,
       decode(tip_deudor,'Importa','S','N') deudor,
       decode(est_cuenta,'Atrasado','A','Vigente','C','Vencido','V','Moroso','M','Gestion','G','Cancelado','N','Pend.Canc.','P','Bloqueo Saldo','S','Inactivo','I','Abierto','A','Bloqueo Cuenta','B','Bloqueo Debito','D','Normal','N','Bloqueo Total','T','Verificacion','X' ) est_cuenta,
       decode(tip_cuenta,'Amortizable','A','No Importa',null,'Plazo fijo','P','Plazo Fijo','P','Doc.Desc','D',tip_cuenta) tip_cuenta,
       decode(tip_prestamo, 'Refinanciado','R','Renovado','N','No Importa',null,'Nuevo','A','Reestructurado','E','Desembolso Nuevo','D','Vista Renovado','V',tip_prestamo) tip_prestamo,
       categoria, observacion
   from ge_tip_asientos_tmp where cod_tip_asiento is not null
   or cod_tip_asiento2 is not null for update of error;
begin
   --- Realizar backup previo
/*   sql_util.ejecute_dml('insert into xx_ge_transacciones_2 select t.*, to_date('||''''||to_char(v_fec_sistema,'dd/mm/yyyy hh24:mi:ss')||''''||','||''''||'dd/mm/yyyy hh24:mi:ss'||''''||') from ge_transacciones t', v_error);
   if v_error is not null then
      raise_application_error(-20000,'Backup de transaccion '||v_error);
   end if;
   sql_util.ejecute_dml('insert into xx_ge_tip_asientos select t.*, to_date('||''''||to_char(v_fec_sistema,'dd/mm/yyyy hh24:mi:ss')||''''||','||''''||'dd/mm/yyyy hh24:mi:ss'||''''||') from ge_tip_asientos t', v_error);
   if v_error is not null then
      raise_application_error(-20000,'Backup de tipos asientos '||v_error);
   end if;*/
   --- Eliminar asiento si se va a recrear
   --- Se reemplazará totalmente el asiento...
   delete ge_tip_asientos t
   where exists (select 1 from ge_tip_asientos_tmp a
                  where a.cod_tip_asiento = t.cod_tip_asiento);
   update ge_tip_asientos_tmp p
      set error = null
    where error is not null;
   for reg in asientos loop
      v_error := null;
      v_cod_tip_asiento := reg.asiento;
/*      --- Verificar si la transaccion posee asiento
      begin
         select nvl(cod_tip_asiento,0) into v_cod_tip_asiento from ge_transacciones
          where cod_modalidad = reg.modalidad
            and cod_transaccion = reg.transaccion;
      exception
         when no_data_found then
            v_error := 'Tran '||reg.transaccion||' Modal '||reg.modalidad||' no registrada';
            goto siguiente_registro;
      end;
*//*      if nvl(reg.asiento,0) <> nvl(v_cod_tip_asiento,0) and nvl(reg.asiento,0) <> 0 then
         v_error := 'Tran '||reg.transaccion||' Modal '||reg.modalidad||' Asi '||reg.asiento||' distinto a '||v_cod_tip_asiento;
         goto siguiente_registro;
      end if;*/
      if nvl(reg.asiento,0) = 0 and nvl(v_cod_tip_asiento,0) = 0 then
         --- Generar siguiente nro. de asiento
         select max(cod_tip_asiento)+1 into v_cod_tip_asiento from ge_tip_asientos;
      end if;
      --- Insertar asiento
      begin
        insert into ge_tip_asientos
           (cod_tip_asiento, nro_linea, cod_rubro, descripcion,
            tip_movimiento, cod_moneda, cod_sec_contable, ind_residente,
            ind_deudor, ind_plazo, ind_producto, tip_renovacion,
            est_cuenta, tip_cuenta, tip_interes, cat_automatica,
            cod_sit_contable)
        values (v_cod_tip_asiento, reg.oficina, reg.rub_contable, reg.observacion,
            reg.movimiento, reg.cod_moneda, reg.cod_sector, reg.residente,
            reg.deudor, reg.plazo, 'N', reg.tip_prestamo,
            reg.est_cuenta, reg.tip_cuenta, null, reg.categoria, null);
      exception
         when others then
            v_error := 'Ins. tip. asiento '||sqlerrm;
            goto siguiente_registro;
      end;
      --- Asociar asiento a transaccion
/*      if nvl(reg.asiento,0) = 0 then
         update ge_transacciones
            set cod_tip_asiento = v_cod_tip_asiento
          where cod_modalidad = reg.modalidad
            and cod_transaccion = reg.transaccion;
      end if;*/
      <<siguiente_registro>>
      update ge_tip_asientos_tmp
         set error = v_error
       where current of asientos;
   end loop;
end prb_tra_asi_masiva;
/

