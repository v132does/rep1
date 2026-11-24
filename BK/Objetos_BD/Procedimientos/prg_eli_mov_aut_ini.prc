CREATE OR REPLACE PROCEDURE IT.PRG_ELI_MOV_AUT_INI
 IS
v_fec_actual ge_calendarios.fec_actual%type;
v_hora ge_movimientos.hora%type:= TO_CHAR(SYSDATE,'HH24:MI:SS');
v_cod_modalidad ge_cuentas.cod_modalidad%type;
v_msj  varchar2(1000) := null;
   cursor reg is
   select nro_cuenta, valor
     from ge_autorizaciones
    where fec_vencimiento < v_fec_actual
      and cod_usu_utilizador is null
      and cod_usuario is null; -- para no tomar autorizaciones de limites a cajeros
BEGIN
   v_fec_actual := pag_cal.fu_obt_fec_actual(1);
   --- Eliminando movimientos de caja
   sql_util.ejecute_dml('TRUNCATE TABLE CJ_MOVIMIENTOS', v_msj);
   if v_msj is not null then
       raise_application_error(-20000, v_msj);
   end if;
   --- Eliminando movimientos diarios
   sql_util.ejecute_dml('TRUNCATE TABLE GE_MOVIMIENTOS', v_msj);
   if v_msj is not null then
       raise_application_error(-20000, v_msj);
   end if;
   -- Eliminando autorizaciones pendientes
   sql_util.ejecute_dml('TRUNCATE TABLE GE_AUT_PEDIDOS', v_msj);
   if v_msj is not null then
       raise_application_error(-20000, v_msj);
   end if;
   -- Eliminando temporal de pago de sueldos.
   --sql_util.ejecute_dml('TRUNCATE TABLE GE_PAG_SUELDOS_TMP', v_msj); -- FQ SC 8193 Comentado porque no debe eliminar los registros de la fecha actual.
   
   --Eliminando temporal de pago de nómina
   delete from ge_pag_sueldos_tmp where nvl(trunc(fec_proceso),trunc(fec_insercion))< trunc(sysdate);
   
   -- Eliminando temporal de pago a proveedores
   delete from ge_pag_proveedores_tmp where trunc(fec_pago)< trunc(sysdate) and tip_carga = 'H'; 
   -- Elimino altas no autorizadas
   delete from ge_pag_sue_emp_tmp where trunc(fec_insercion) < trunc(sysdate) and estado = 'P';
   if v_msj is not null then
       raise_application_error(-20000, v_msj);
   end if;
   -- Eliminando temporal de pago de recaudaciones
   delete from ge_pag_recaudaciones_tmp where trunc(fec_insercion)<trunc(sysdate);
   
   --Actualizar los maestros, aut_pendiente = 'N'
   for i in reg loop
     begin
       select cod_modalidad
         into v_cod_modalidad
         from ge_cuentas
        where nro_cuenta = i.nro_cuenta;

       If v_cod_modalidad is not null then
         If v_cod_modalidad = 31 then
           update ah_cta_vistas set aut_pendiente = 'N'
            where nro_cuenta = i.nro_cuenta
              and aut_pendiente = 'S';
         elsif v_cod_modalidad = 33 then
           update ah_cta_certificados set aut_pendiente = 'N'
            where nro_cuenta = i.nro_cuenta
              and aut_pendiente = 'S';
         elsif v_cod_modalidad = 41 then
           update cc_cta_corrientes set aut_pendiente = 'N'
            where nro_cuenta = i.nro_cuenta
              and aut_pendiente = 'S';
         End if;
       End if;
       --actualiza saldo bloqueado de la cuenta
       if v_cod_modalidad in (31,33,41) then
         v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
         PAG_CTA.PR_ACT_SAL_CTA(i.nro_cuenta,
                     v_cod_modalidad,
                     'D',             ---TIP_MOVIMIENTO
                     v_fec_actual,    --- FECHA
                     v_hora,          --- HORA
                     null,            --- SAL_TOTAL
                     null,            --- SAL_RETENIDO
                     i.valor,         ---SAL BLOQUEADO
                     'N',             --- AUT_PENDIENTE
                     'S');
       end if;

     exception
       when no_data_found then
         null;
     end;
   end loop;
   -- Borrando autorizaciones pendientes
   delete ge_autorizaciones
   where fec_vencimiento < v_fec_actual
   and cod_usu_utilizador is null; --- Vencidas y No utilizadas
   -- CRO-JM-03/2015: CROGEFIT-3 Borrando cj_acu_imp_transacciones:
   delete from cj_acu_imp_transacciones;
END;
/

