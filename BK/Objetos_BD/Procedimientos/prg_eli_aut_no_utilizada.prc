CREATE OR REPLACE PROCEDURE IT.PRG_ELI_AUT_NO_UTILIZADA
 IS
 -- elimina autorizaciones previas no utilizadas
v_fec_actual ge_calendarios.fec_actual%type;
v_hora ge_movimientos.hora%type:= TO_CHAR(SYSDATE,'HH24:MI:SS');
v_cod_modalidad ge_cuentas.cod_modalidad%type;
v_msj  varchar2(1000) := null;
   cursor reg is
   select nro_cuenta, valor, cod_usuario
     from ge_autorizaciones
    where fec_vencimiento <= v_fec_actual
      and cod_usu_utilizador is null
      and cod_usuario is null; -- no tomar limites de cajeros
BEGIN
   v_fec_actual := pag_cal.fu_obt_fec_actual(1);
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
         --sólo las autorizaciones ingresadas por Aut. Previas debe tomar, no las que entraron por Aut. Previas de Caja (estas no bloquean saldo) VC 16-09-2010
         if i.cod_usuario is null then 
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
       end if;
                    
     exception
       when no_data_found then
         null;
     end;
   end loop;

   -- Borrando autorizaciones pendientes
   delete ge_autorizaciones
   where fec_vencimiento <= v_fec_actual
   and cod_usu_utilizador is null; --- Vencidas y No utilizadas
END;
/

