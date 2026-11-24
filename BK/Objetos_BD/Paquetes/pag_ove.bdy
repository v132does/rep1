CREATE OR REPLACE PACKAGE BODY IT.PAG_OVE IS
/* Permite obtener los datos de la operacion vencida. */
PROCEDURE PR_OBT_DAT_OPE_VENCIDA
 (P_NRO_CUENTA IN GE_OPE_VENCIDAS.NRO_CUENTA%TYPE
 ,RP_GOPVEN IN OUT GE_OPE_VENCIDAS%ROWTYPE
 )
 IS
BEGIN
   select *
     into rp_gopven
     from ge_ope_vencidas --x nro. de cuenta original
    where nro_cuenta = p_nro_cuenta;
exception
   when no_data_found then
      raise_application_error(-20000,'Cuenta Vencida '||p_nro_cuenta||' no registrada');
END;

PROCEDURE PR_OBT_DEU_OPE_VENCIDA
 (P_NRO_CUENTA IN GE_OPE_VENCIDAS.NRO_CUENTA%TYPE
 ,P_FECHA IN DATE
 ,P_MTO_COBRADO IN GE_OPE_VENCIDAS.SAL_INTERES%TYPE
 ,P_MTO_GASTOS IN GE_OPE_VENCIDAS.SAL_INTERES%TYPE
 ,P_ERROR IN OUT NUMBER
 ,P_MENSAJE IN OUT VARCHAR2
 ,P_TOT_CAPITAL IN OUT GE_OPE_VENCIDAS.SAL_INTERES%TYPE
 ,P_TOT_MORATORIO IN OUT GE_OPE_VENCIDAS.SAL_INTERES%TYPE
 ,P_TOT_PUNITORIO IN OUT GE_OPE_VENCIDAS.SAL_INTERES%TYPE
 ,P_TOT_IMPUESTO IN OUT GE_OPE_VENCIDAS.SAL_INTERES%TYPE
 ,P_GASTOS IN OUT GE_OPE_VENCIDAS.SAL_INTERES%TYPE
 ,P_CANCELA IN VARCHAR2 default 'N'
 )
 IS

/* Recupera la exoneracion de impuestos de la cuenta */
FUNCTION FU_OBT_EXO_IMPUESTO
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2;
   r_gopeven           ge_ope_vencidas%rowtype;
   --- Variables auxiliares
   v_sal_cobrado       ge_ope_vencidas.sal_interes%type;
   v_sal_capital       ge_ope_vencidas.sal_interes%type;
   v_moratorio         ge_ope_vencidas.sal_int_moratorio%type;
	 v_sal_impuesto      ge_ope_vencidas.sal_impuesto%type;
   v_cargo             ge_ope_vencidas.sal_interes%type;
   v_cargo_iva         ge_ope_vencidas.sal_interes%type;
   v_punitorio         ge_ope_vencidas.sal_int_punitorio%type;
   v_tot_capital       ge_ope_vencidas.sal_interes%type;
   v_tot_moratorio     ge_ope_vencidas.sal_int_moratorio%type;
   v_tot_impuesto      ge_ope_vencidas.sal_impuesto%type;
   v_tot_cargo         ge_ope_vencidas.sal_interes%type;
   v_tot_punitorio     ge_ope_vencidas.sal_int_punitorio%type;
   v_cod_mon_local     ba_monedas.cod_moneda%type;
   --- Variables auxiliares para utilizacion de interes
   --v_redondeo number(1);
   v_exo_impuesto       pr_cta_prestamos.exo_impuestos%type;

/* Recupera la exoneracion de impuestos de la cuenta */
FUNCTION FU_OBT_EXO_IMPUESTO
 (P_NRO_CUENTA IN PR_CTA_PRESTAMOS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2 IS
   v_exo_impuestos ge_clientes.exo_impuestos%type;
BEGIN
   select nvl(exo_impuestos,'N')
     into v_exo_impuestos
     from ge_clientes cli, ge_cta_clientes cct
    where cct.cod_persona = cli.cod_persona
      and cct.nro_cuenta  = p_nro_cuenta
      and cct.relacion    = 'P';
   return v_exo_impuestos;
END;
BEGIN
   --- Recuperar datos de la operacion
   pag_ove.pr_obt_dat_ope_vencida(p_nro_cuenta, r_gopeven);
   v_cod_mon_local          := pag_gen.fu_obt_mon_local;
   --v_exo_impuesto           := FU_OBT_EXO_IMPUESTO(p_nro_cuenta);
   /*v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',r_gopeven.cod_modulo,r_gopeven.cod_modalidad,r_gopeven.cod_moneda,r_gopeven.cod_oficina);
   if r_gopeven.cod_moneda = v_cod_mon_local then
      v_redondeo := 0;
   else
      v_redondeo := 2;
   end if;*/
   --- Inicializar totales
   v_tot_capital      := 0;
   v_tot_moratorio    := 0;
   v_tot_impuesto     := 0;
   v_tot_punitorio    := 0;
   v_sal_capital      := 0;
   v_moratorio        := 0;
   v_cargo_iva        := 0;
   --- Monto cobrado --- se cobra en base al mismo
   v_sal_cobrado := p_mto_cobrado;

   --- Recuperar saldo capital
   v_sal_capital := r_gopeven.sal_total;
   v_punitorio   := r_gopeven.sal_int_punitorio;
   v_moratorio   := r_gopeven.sal_int_moratorio;
   v_cargo       := nvl(P_MTO_GASTOS,0); --los cargos ingresados

   -- Calcula el impuesto
   --IF v_exo_impuesto = 'N' Then
     --- Calcular impuesto, ya se tiene en la tabla
   v_sal_impuesto := r_gopeven.sal_impuesto;
   --End if;
   if  nvl(v_sal_cobrado,0) > 0 then
      --minimamente debe cubrir el cargo
      if nvl(v_cargo,0) > 0 then --cargos
         if v_sal_cobrado >= v_cargo then
				    v_sal_cobrado := v_sal_cobrado - v_cargo;
            --porcion cobrada
            v_tot_cargo := v_cargo;
         else
            --minimamente debe cubrir el cargo
            return;
         end if;
      end if;
      if nvl(v_sal_impuesto,0) > 0 then --- impuesto
         if v_sal_cobrado >= v_sal_impuesto then
           v_sal_cobrado := v_sal_cobrado - v_sal_impuesto;
           v_tot_impuesto := v_sal_impuesto;
         else
           v_tot_impuesto :=  v_sal_cobrado;--v_impuesto - v_sal_cobrado;
           v_sal_cobrado := 0;
         end if;
      end if;
      if nvl(v_punitorio,0) > 0 then --- punitorio
         if v_sal_cobrado >= v_punitorio then
           v_sal_cobrado := v_sal_cobrado - v_punitorio;
           v_tot_punitorio := v_punitorio;
         else
           v_tot_punitorio :=  v_sal_cobrado;--v_punitorio - v_sal_cobrado;
           v_sal_cobrado := 0;
         end if;
      end if;
      if nvl(v_moratorio,0) > 0 then --- moratorio
         if v_sal_cobrado >= v_moratorio then
           v_sal_cobrado := v_sal_cobrado - v_moratorio;
           v_tot_moratorio := v_moratorio;
         else
           v_tot_moratorio := v_sal_cobrado;--v_moratorio - v_sal_cobrado;
           v_sal_cobrado := 0;
         end if;
      end if;
      if  nvl(v_sal_capital,0) > 0 then --capital
         if v_sal_cobrado >= v_sal_capital then
				   v_sal_cobrado := v_sal_cobrado - v_sal_capital;
           v_tot_capital := v_sal_capital;
         else
 					 v_tot_capital :=  v_sal_cobrado;--v_sal_capital - v_sal_cobrado;
           v_sal_cobrado := 0;
         end if;
      end if;
   else
      --mto cobrado es cero
      return;
   end if;

   --- Cargar parametros de salida, porciones cobradas
   p_tot_capital    := v_tot_capital;
   p_tot_moratorio  := v_tot_moratorio;
   p_gastos         := v_tot_cargo;
   p_tot_impuesto   := v_tot_impuesto;
   p_tot_punitorio  := v_tot_punitorio;
exception
  when others then
    p_error   := 20002;
    p_mensaje := sqlerrm;
END;

PROCEDURE PR_COB_OPE_VENCIDA
 (P_NRO_CUENTA IN GE_OPE_VENCIDAS.NRO_CUENTA%TYPE
 ,P_MTO_COBRADO IN GE_OPE_VENCIDAS.SAL_INTERES%TYPE
 ,p_MTO_GASTOS IN GE_OPE_VENCIDAS.SAL_INTERES%TYPE
 ,P_COD_OFI_ORIGEN IN GE_MOVIMIENTOS.COD_OFI_ORIGEN%TYPE
 ,P_CONCEPTO IN GE_MOVIMIENTOS.CONCEPTO%TYPE
 ,P_FECHA IN GE_MOVIMIENTOS.FECHA%TYPE
 ,P_HORA IN OUT GE_MOVIMIENTOS.HORA%TYPE
 ,P_NRO_SECUENCIA IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE
 ,P_COD_TRA_PADRE IN NUMBER default 139
 ,P_COD_MOD_PADRE IN NUMBER
 ,P_COD_MAD_PADRE IN NUMBER
 ,p_NRO_OPERACION IN NUMBER)
 IS

 RETURN NUMBER;
--- Datos del registros de cuentas
   r_gopeven       ge_ope_vencidas%rowtype;
   r_gmovi         ge_movimientos%rowtype;
   v_mto_ant       ge_ope_vencidas.sal_interes%type;
   v_cargo         ge_ope_vencidas.sal_interes%type;
   v_cargo_iva     ge_ope_vencidas.sal_interes%type;
   v_cancela       varchar2(01);
   v_error         number(05);
   v_mensaje       varchar2(1000);
   --- Variables de movimientos
   v_nro_secuencia ge_movimientos.nro_secuencia%type;
   v_hora          ge_movimientos.hora%type;
   v_est_movim     ge_movimientos.estado%type;
   v_mto_cobrado   ge_ope_vencidas.sal_interes%type;
   v_capital       ge_ope_vencidas.sal_interes%type;
   v_moratorio     ge_ope_vencidas.sal_int_moratorio%type;
   v_punitorio     ge_ope_vencidas.sal_int_punitorio%type;
   v_impuesto      ge_ope_vencidas.sal_impuesto%type;
   v_gastos        ge_ope_vencidas.sal_interes%type;
   v_cod_tasa      ge_tasas.cod_tasa%type := null;
   v_val_tas_iva   ge_tas_fechas.val_tasa%type;
   v_fec_vigencia  ge_tas_fechas.fec_vigencia%type;
   v_tip_valor     ge_tasas.tip_valor%type;
   v_tipo          ge_tasas.tipo%type;
   v_cal_fac       number;
   v_cal_fac_iva   number;
   v_redondeo      number(1);
   v_cod_mon_local ba_monedas.cod_moneda%type;
BEGIN
--  begin pre_ini_aplicacion; pae_cnf.G_COD_MODULO:= 1; end;
   --- Inicializar datos del movimiento
   v_hora          := nvl(p_hora,to_char(sysdate,'HH24:MI:SS'));
   v_nro_secuencia := nvl(p_nro_secuencia,0);
   v_mto_cobrado   := nvl(p_mto_cobrado,0);
   v_est_movim     := 'N';
   v_cod_mon_local := pag_gen.fu_obt_mon_local;

   --recuperar datos de la operacion vencida
   pag_ove.pr_obt_dat_ope_vencida(p_nro_cuenta,r_gopeven);

   v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',r_gopeven.cod_modulo, r_gopeven.cod_modalidad,r_gopeven.cod_moneda);

   --calcular deuda y porciones cobradas
   pag_ove.pr_obt_deu_ope_vencida(p_nro_cuenta,p_fecha,
                p_mto_cobrado, p_mto_gastos, v_error,v_mensaje,v_capital,v_moratorio,
                v_punitorio,v_impuesto,v_gastos,v_cancela);
   if v_error is not null then
      raise_application_error(-20000, v_mensaje);
   end if;

   --verificar si se cobra algo
   if p_mto_cobrado > 0 then
     if (nvl(v_capital,0) + nvl(v_moratorio,0) + nvl(v_punitorio,0) +
      nvl(v_impuesto,0) + nvl(v_gastos,0)) <= 0 then
        raise_application_error(-20000,'Mtos. a cobrar no corresponden.');
     end if;
   else
     raise_application_error(-20000,'Mto. cobrado debe ser mayor a cero. '||p_mto_cobrado);
   end if;

   --recuperar iva sobre comisiones cobradas ??????
--   if v_exo_impuesto = 'N' then
      v_cod_tasa := null;
      pag_gen.pr_obt_val_tasa(r_gopeven.cod_modulo, r_gopeven.cod_modalidad,
                      r_gopeven.cod_oficina, r_gopeven.nro_cuenta, r_gopeven.cod_moneda,
                      r_gopeven.dia_atraso, 'N', v_cod_tasa, 517, --Transaccion
                      p_fecha, v_val_tas_iva, v_fec_vigencia, v_tip_valor, v_tipo);
      v_cal_fac_iva := 100 / (100 + v_val_tas_iva);
      --- Calcular cuanto corresponde al impuesto
      v_mto_ant    := nvl(v_gastos,0);
      v_cargo      := round(v_mto_ant * nvl(v_cal_fac_iva,0),v_redondeo);
      -----
      v_cargo_iva  := nvl(v_mto_ant,0) - nvl(v_cargo,0);
      v_cargo      := nvl(v_cargo,0) + nvl(v_cargo_iva,0);
--    end if;

    --- GENERAR MOVIMIENTOS x las porciones cobradas
    --mov. principal -> x el gasto
    r_gmovi.cod_usuario    := user;
    r_gmovi.hora           := v_hora;
    r_gmovi.fecha          := p_fecha;
    r_gmovi.cod_modulo     := r_gopeven.cod_modulo;
    r_gmovi.cod_modalidad  := r_gopeven.cod_modalidad;
    r_gmovi.cod_oficina    := r_gopeven.cod_oficina;
    r_gmovi.nro_cuenta     := p_nro_cuenta;
    r_gmovi.cod_moneda     := r_gopeven.cod_moneda;
    r_gmovi.est_cuenta     := r_gopeven.estado;
    r_gmovi.cod_tra_padre  := p_cod_tra_padre;
    r_gmovi.cod_mod_padre  := p_cod_mod_padre;
    r_gmovi.cod_mad_padre  := p_cod_mad_padre;
    r_gmovi.fec_valor      := p_fecha;
    r_gmovi.reversado      := 'N';
    r_gmovi.protegido      := 'N';
    r_gmovi.estado         := 'N';
    r_gmovi.cod_ofi_origen := p_cod_ofi_origen;
    r_gmovi.nro_documento  := p_nro_operacion;--r_gopeven.nro_cta_origen; -- la cuenta origen
    r_gmovi.concepto       := nvl(p_concepto,'Cobro Operacion Vencida');
    --se genera movimiento x el gasto
    IF (v_cargo - v_cargo_iva) > 0 THEN -- se cobra gastos
       v_nro_secuencia            := v_nro_secuencia + 1;
       r_gmovi.nro_secuencia      := v_nro_secuencia;
       r_gmovi.emi_aviso          := 'S';
       r_gmovi.cod_transaccion    := 712;
       r_gmovi.monto              := v_cargo - v_cargo_iva;
       pag_gen.pr_ins_ge_movimiento(r_gmovi);
    END IF;
    --se genera movimiento x el iva del cargo
    IF v_cargo_iva > 0 THEN -- se cobra gastos
       v_nro_secuencia            := v_nro_secuencia + 1;
       r_gmovi.nro_secuencia      := v_nro_secuencia;
       r_gmovi.emi_aviso          := 'S';
       r_gmovi.cod_transaccion    := 517;
       r_gmovi.monto              := v_cargo_iva;
       pag_gen.pr_ins_ge_movimiento(r_gmovi);
    END IF;
    ---se generan datos de cobro impuestos
    if v_impuesto > 0 then --- se cobra impuestos
       -- inserta monto interes cobrado
       v_nro_secuencia             := v_nro_secuencia + 1;
       r_gmovi.nro_secuencia       := v_nro_secuencia;
       r_gmovi.emi_aviso           := 'S';
       r_gmovi.cod_transaccion     := 713;
       r_gmovi.monto               := v_impuesto;
       pag_gen.pr_ins_ge_movimiento(r_gmovi);
    end if;
    --- generar movimiento por el interes punitorio
    if nvl(v_punitorio,0) > 0 then --se cobra punitorio
       v_nro_secuencia             := v_nro_secuencia + 1;
       r_gmovi.nro_secuencia       := v_nro_secuencia;
       r_gmovi.emi_aviso           := 'S';
       r_gmovi.cod_transaccion     := 820;
       r_gmovi.monto               := v_punitorio;
       pag_gen.pr_ins_ge_movimiento(r_gmovi);
    end if;
    -- generar movimiento por el interes moratorio
    if nvl(v_moratorio,0) > 0 then --se cobra moratorio
       v_nro_secuencia             := v_nro_secuencia + 1;
       r_gmovi.nro_secuencia       := v_nro_secuencia;
       r_gmovi.emi_aviso           := 'S';
       r_gmovi.cod_transaccion     := 830;
       r_gmovi.monto               := v_moratorio;
       pag_gen.pr_ins_ge_movimiento(r_gmovi);
    end if;
    -- generar movimiento por el capital
    if nvl(v_capital,0) > 0 then --se cobra capital
       v_nro_secuencia             := v_nro_secuencia + 1;
       r_gmovi.nro_secuencia       := v_nro_secuencia;
       r_gmovi.emi_aviso           := 'S';
       r_gmovi.cod_transaccion     := 819;--actualiza saldo batch
       r_gmovi.monto               := v_capital;
       pag_gen.pr_ins_ge_movimiento(r_gmovi);
       --verifica si cancela -> si paga todo el capital es cancelacion
       if r_gopeven.sal_total - v_capital = 0 then
          v_cancela :='S';
       end if;
    end if;
    --ver si cancela -> actualizar el estado
    if v_cancela = 'S' then
       --generar movimiento
       r_gmovi.monto           := null;
       v_nro_secuencia         := v_nro_secuencia + 1;
   		 r_gmovi.nro_secuencia   := v_nro_secuencia;
			 r_gmovi.cod_modulo      := r_gopeven.cod_modulo;
			 r_gmovi.cod_modalidad   := r_gopeven.cod_modalidad;
			 r_gmovi.cod_oficina     := r_gopeven.cod_oficina;
			 r_gmovi.cod_moneda      := r_gopeven.cod_moneda;
       r_gmovi.nro_cuenta      := p_nro_cuenta;
			 r_gmovi.cod_tra_padre   := 401;
			 r_gmovi.cod_mod_padre   := p_cod_mod_padre;
			 r_gmovi.cod_mad_padre   := p_cod_mad_padre;
			 r_gmovi.cod_transaccion := 401;
			 r_gmovi.cod_ofi_origen  := p_cod_ofi_origen;
			 r_gmovi.concepto        := 'Cambio de estado Operacion Vencida';
			 r_gmovi.emi_aviso       := 'N';
			 r_gmovi.estado          := 'N';
			 r_gmovi.reversado       := 'N';
       r_gmovi.protegido       := 'N';
       r_gmovi.est_cuenta      := 'C'; --cancelada
       pag_gen.PR_INS_GE_MOVIMIENTO(r_gmovi);
    end if;

    --actualizar los saldos de la operacion vencida
    update ge_ope_vencidas
       set sal_int_punitorio  = nvl(sal_int_punitorio,0) - nvl(v_punitorio,0),
           sal_int_moratorio  = nvl(sal_int_moratorio,0) - nvl(v_moratorio,0),
           sal_impuesto       = nvl(sal_impuesto,0) - nvl(v_impuesto,0),
           sal_total          = nvl(sal_total,0) - nvl(v_capital,0),
           fec_ult_movimiento = p_fecha,
           hor_ult_movimiento = v_hora,
           estado             = decode(v_cancela,'S','C',estado),
           fec_cam_estado     = decode(v_cancela,'S',p_fecha,fec_cam_estado)
     where nro_cuenta = p_nro_cuenta;

   p_nro_secuencia := v_nro_secuencia;
exception
   when others then
      if sqlcode  <= -20000 then
         raise;
      else
         raise_application_error(-20000,'Cobro.Ven. '||sqlerrm);
      end if;
END;
END PAG_OVE;
/

