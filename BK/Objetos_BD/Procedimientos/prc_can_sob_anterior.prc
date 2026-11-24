CREATE OR REPLACE PROCEDURE IT."PRC_CAN_SOB_ANTERIOR" IS
--Definicion de Variables--
RV_GCALE GE_CALENDARIOS%ROWTYPE;
v_fec_actual DATE;
V_HORA GE_MOVIMIENTOS.HORA%TYPE;
v_fec_anterior GE_CALENDARIOS.FEC_ANTERIOR%TYPE;

--Definicion de Cursores--
cursor mov is
select distinct hora, cod_usuario
  from cc_movimientos_his
 where fecha = v_fec_anterior
   and cod_modulo = 4
   and cod_modalidad = 41
   and cod_transaccion in (902,909,900,912,  -- sobregiro sin acuerdo,
                           942,949,940,952)  -- sobregiro con acuerdo
   and monto > 0
   order by hora;
BEGIN
   --Traer los Datos de las Fechas--
   v_fec_actual := pag_cal.fu_obt_fec_actual(4);
   rv_gcale  := pag_cal.fu_obt_reg_cal(4);
   v_fec_anterior := rv_gcale.fec_anterior;

   --Inicializa Hora para los Movimientos--
   --v_hora    := fug_ini_hora(sysdate, 'HH24:MI:SS');
   --FQ Para evitar error de PK
   v_hora := to_char(sysdate,'HH24:MI:SS');
   v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');

   --Inserto en ge_movimientos movimientos inversos
   --a los sobregiros del dia anterior
   for reg in mov loop
      insert into ge_movimientos
            (cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
             cod_tra_padre,cod_transaccion,fecha,fec_valor,
             monto,estado,concepto,reversado,
             cod_mod_padre,cod_mad_padre,cod_usuario,hora,
             nro_secuencia,nro_cuenta,cod_ofi_origen)
      select cod_modulo,cod_modalidad,cod_oficina,cod_moneda,
             cod_tra_padre,cod_transaccion,v_fec_actual,v_fec_actual,
             monto * -1,estado,'Cancelación Sobregiros',reversado,
             cod_mod_padre,cod_mad_padre,user, v_hora,
             nro_secuencia,nro_cuenta,cod_ofi_origen
        from CC_MOVIMIENTOS_HIS
       where fecha = v_fec_anterior
         and hora = reg.hora
         and cod_usuario = reg.cod_usuario
         and cod_modulo = 4
         and cod_modalidad = 41
         and cod_transaccion in (902,909,900,912,  -- sobregiro sin acuerdo,
                                 942,949,940,952)  -- sobregiro con acuerdo
         and monto > 0
         order by nro_secuencia;
      --obtener sig segundo para el prox ciclo
      --v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      --FQ Para evitar error de PK
      v_hora := fug_obt_hor_disponible(v_fec_actual,v_hora,user,'N');
   end loop;
--------------------------------------------------------------------
EXCEPTION
 WHEN OTHERS THEN
    raise_application_error(-20000, 'ERROR. prc_can_sob_anterior '||SQLERRM);
END prc_can_sob_anterior;
/
