CREATE OR REPLACE PACKAGE BODY IT.PAL_CIE is
---
g_nro_cuenta     ge_cuentas.nro_cuenta%type;
g_cod_modulo     ba_modulos.cod_modulo%type;
g_cod_modalidad  ge_modalidades.cod_modalidad%type;
---
/*Funcion local q retorna la persona relacionada a la entidad*/
FUNCTION LF_OBT_PER_ENTIDAD
return varchar2
 IS
v_cod_persona ge_par_generales.cod_persona%type;
BEGIN
   select cod_persona
   into v_cod_persona
   from ge_par_generales;
   return v_cod_persona;
exception
   when no_data_found then
     raise_application_error(-20000,
     'Parametro general no registrado');
   when too_many_rows then
     raise_application_error(-20000,
     'Parametro general duplicado');
end;

/*Proceso que registra movimientos de venta por el devengamiento de ahorros
en moneda extranjera. Se correra en el cierre */
PROCEDURE PR_PRO_DEV_AHORROS IS

v_fec_actual         date := pag_cal.fu_obt_fec_actual(7); --fecha de hoy
v_cod_modalidad      NUMBER(04);
v_cod_oficina        NUMBER(03);
v_cod_moneda         varchar2(03);
v_tot_interes        NUMBER := 0;
v_hora               varchar2(08);
v_tot_mon_local      NUMBER;
v_cotizacion         ge_cotizaciones.val_conversion%type;
v_cod_tip_operacion  lc_tip_operaciones.cod_tip_operacion%type := 31; -- fijo venta cuenta contable
v_cod_tip_ope_bcp    lc_tip_operaciones.cod_tip_ope_bcp%type;
r_gmovi              ge_movimientos%rowtype;
r_rpoca              lc_bol_automaticos_res%rowtype;
--v_nro_secuencia      ge_movimientos.nro_secuencia%type :=0;
v_mon_local          ba_monedas.cod_moneda%type :=  pag_gen.fu_obt_mon_local;
v_nro_operacion      ge_movimientos.nro_documento%type;
v_redondeo           number(5);
v_usu_mig_excluir    varchar2(30);

CURSOR CUR_DATOS IS
    SELECT COD_MODALIDAD,cod_oficina COD_OFI_CAMBIO, AH_DEVENGADOS.COD_MONEDA,SUM(MTO_INTERES)--MTO_DEV_ACTUAL
      FROM GE_CUENTAS, AH_DEVENGADOS
     WHERE FECHA = v_fec_actual
       AND AH_DEVENGADOS.COD_MONEDA <> v_mon_local
       AND GE_CUENTAS.NRO_CUENTA = AH_DEVENGADOS.NRO_CUENTA
       and (v_usu_mig_excluir is null or AH_DEVENGADOS.usu_insercion <> v_usu_mig_excluir)
     GROUP BY COD_MODALIDAD,cod_oficina,AH_DEVENGADOS.COD_MONEDA
     HAVING SUM(MTO_INTERES) <> 0;

BEGIN
   v_usu_mig_excluir := fug_obt_pardinamico('COD_USU_MIG_EXCLUIR');
   --
   select cod_tip_ope_bcp
     into v_cod_tip_ope_bcp
     from lc_tip_operaciones
    where cod_tip_operacion = v_cod_tip_operacion;
   --------------------------------------------------------------
   IF CUR_DATOS%ISOPEN THEN
      CLOSE CUR_DATOS;
   END IF;
   OPEN CUR_DATOS;
   --v_hora := fug_ini_hora(SYSDATE,'HH24:MI:SS');

   --wa:para pk
   v_hora := to_char(sysdate,'HH24:MI:SS');
   v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');
   LOOP
      FETCH CUR_DATOS INTO v_cod_modalidad,v_cod_oficina,v_cod_moneda,v_tot_interes;
      EXIT WHEN CUR_DATOS%NOTFOUND;
      -----------------------------------------------------------
      v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, 72, v_cod_moneda, v_cod_oficina)+1;
      prg_act_par_dinamico('NRO_RECIBO',7, 72, v_cod_moneda, v_cod_oficina, v_nro_operacion);

      v_cotizacion := pag_gen.FU_OBT_COTIZACION(v_cod_moneda,v_fec_actual);
      v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,v_cod_modalidad,v_mon_local);
      v_tot_mon_local := ROUND(NVL(v_cotizacion,0) * v_tot_interes,v_redondeo);
      --- genera movimiento ---
      --v_nro_secuencia       := 1;
      r_gmovi.cod_usuario   := user;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := 1; -- FIJO 1 para que tome los reportes de cambios
      r_gmovi.cod_modulo    := 7;
      r_gmovi.cod_modalidad := 72;
      r_gmovi.cod_oficina   := v_cod_oficina;
      r_gmovi.nro_cuenta    := null;
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.fec_valor     := v_fec_actual;
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.cod_tra_padre   := 901;
      r_gmovi.cod_transaccion := 901;
      r_gmovi.nro_documento  := v_nro_operacion;
      r_gmovi.nro_documento2 := null;
      r_gmovi.monto          := v_tot_interes;
      r_gmovi.estado         := 'N';
      r_gmovi.cod_ofi_origen := v_cod_oficina;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      r_gmovi.cod_mod_padre := 7;
      r_gmovi.cod_mad_padre := 72;
      r_gmovi.concepto      := 'Deveng.Int. Cart.Pas. Mod: '||v_cod_modalidad;
      r_gmovi.cotizacion    := v_cotizacion;
      r_gmovi.mto_equ_local := v_tot_mon_local;
      r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
      r_gmovi.COD_BCO_CENTRAL := v_cod_tip_ope_bcp;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

       --insertar movimientos en la Tabla de Posición de Cambios
      r_rpoca.cod_usuario   := user;
      r_rpoca.hora          := v_hora;
      r_rpoca.cod_oficina   := v_cod_oficina;
      r_rpoca.cod_moneda    := v_cod_moneda;
      r_rpoca.fecha         := v_fec_actual;
      r_rpoca.cod_modulo    := 7;
      r_rpoca.cod_modalidad := 72;
      r_rpoca.cod_tra_padre   := 901;
      r_rpoca.cod_transaccion := 901;
      r_rpoca.nro_documento  := v_nro_operacion;
      r_rpoca.monto          := v_tot_interes;
      r_rpoca.cod_mod_padre := 7;
      r_rpoca.cod_mad_padre := 72;
      r_rpoca.concepto      := 'Deveng.Int.Cart.Pas. Mod: '||v_cod_modalidad;
      g_cod_modalidad       := v_cod_modalidad;
      r_rpoca.cotizacion    := v_cotizacion;
      r_rpoca.mto_equ_local := v_tot_mon_local;
      r_rpoca.cod_tip_ope_cambio := v_cod_tip_operacion;
      r_rpoca.COD_BCO_CENTRAL := v_cod_tip_ope_bcp;
      r_rpoca.referencia    := 'VTA_DEV_AHORROS';
      pal_cie.pr_ins_bol_automaticas(r_rpoca);

      --- genera movimiento x persona, para listados ---
      --v_nro_secuencia       := 1;
      r_gmovi.cod_usuario   := user;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := 2; -- FIJO para que tome los reportes de cambios
      r_gmovi.cod_modulo    := 7;
      r_gmovi.cod_modalidad := 70;
      r_gmovi.cod_oficina   := v_cod_oficina;
      r_gmovi.nro_cuenta    := null;
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.fec_valor     := v_fec_actual;
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.cod_tra_padre   := 901;
      r_gmovi.cod_transaccion := 760;
      r_gmovi.nro_documento := v_nro_operacion;
      r_gmovi.nro_documento2 := LF_OBT_PER_ENTIDAD;
      r_gmovi.monto         := 0;
      r_gmovi.estado        := 'N';
      r_gmovi.cod_ofi_origen := v_cod_oficina;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      r_gmovi.cod_mod_padre := 7;
      r_gmovi.cod_mad_padre := 72;
      r_gmovi.concepto      := 'Deveng.Int. Cart.Pas. Mod: '||v_cod_modalidad;
      r_gmovi.cotizacion    := null;
      r_gmovi.mto_equ_local := null;
      r_gmovi.cod_tip_ope_cambio := null;
      r_gmovi.COD_BCO_CENTRAL    := v_cod_tip_ope_bcp;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
      --wa:para pk
      v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');
      --actualizar posicion
      UPDATE LC_POSICIONES SET
             MTO_VTA_NEF_ACT = NVL(MTO_VTA_NEF_ACT,0) + v_tot_interes,
             MTO_VTA_NEF_LOC = NVL(MTO_VTA_NEF_LOC,0) + v_tot_mon_local
       WHERE COD_TIP_OPE_BCP = v_cod_tip_ope_bcp
         AND COD_MONEDA = v_cod_moneda
         AND COD_OFI_CAMBIO = PAL_CAM.FU_OBT_OFI_CAMBIO(v_cod_oficina);
      --insertar posicion si no existe
      IF SQL%NOTFOUND THEN
         INSERT INTO LC_POSICIONES
             (COD_MONEDA,COD_TIP_OPE_BCP,COD_OFI_CAMBIO,
              MTO_VTA_NEF_ACT,MTO_VTA_NEF_LOC)
         VALUES
             (v_cod_moneda, v_cod_tip_ope_bcp,PAL_CAM.FU_OBT_OFI_CAMBIO(v_cod_oficina),
              v_tot_interes,v_tot_mon_local);
      END IF;
   END LOOP;
   IF CUR_DATOS%ISOPEN THEN
      CLOSE CUR_DATOS;
   END IF;
END;

/*Proceso que registra movimientos de compra por el devengamiento de prestamos
en moneda extranjera. Se correra en el cierre*/
PROCEDURE PR_PRO_DEV_PRESTAMOS IS

v_fec_actual        date := pag_cal.fu_obt_fec_actual(7); --fecha de hoy
v_cod_modalidad     NUMBER(04);
v_cod_oficina       NUMBER(03);
v_cod_moneda        varchar2(03);
v_tot_interes       NUMBER := 0;
v_hora              varchar2(08);
v_tot_mon_local     NUMBER;
v_cotizacion        ge_cotizaciones.val_conversion%type;
v_cod_tip_operacion lc_tip_operaciones.cod_tip_operacion%type := 17; -- fijo compra cuenta contable
v_cod_tip_ope_bcp   lc_tip_operaciones.cod_tip_ope_bcp%type;
r_gmovi ge_movimientos%rowtype;
r_rpoca              lc_bol_automaticos_res%rowtype;
--v_nro_secuencia ge_movimientos.nro_secuencia%type :=0;
v_mon_local ba_monedas.cod_moneda%type :=  pag_gen.fu_obt_mon_local;
v_nro_operacion ge_movimientos.nro_documento%type;
v_redondeo          number(5);
v_usu_mig_excluir   varchar2(30);
CURSOR CUR_DATOS IS
   SELECT ct.COD_MODALIDAD,ct.cod_oficina COD_OFI_CAMBIO, d.COD_MONEDA,SUM(MTO_DEV_ACTUAL)
     FROM GE_PLZ_CONTABLES PC, PR_DEVENGADOS D, PR_CTA_PRESTAMOS CT,
          GE_CLIENTES C, GE_CTA_CLIENTES CC, GE_MODALIDADES MO
    WHERE D.FECHA = v_fec_actual
      AND D.NRO_CUENTA = CT.NRO_CUENTA
      AND D.NRO_CUENTA = CC.NRO_CUENTA
      AND RELACION = 'P'
     -- AND (CT.ESTADO = 'C' AND D.CATEGORIA < 3)-- AP 2809 Solo considerar devengados de prestamos vigentes, estos afectan a rubros de perdida/ganancia
      /*dydmr 1796 28/04/2015 FM */
      AND ((CT.ESTADO = 'C' AND D.CATEGORIA < 3) or (CT.ESTADO = 'N' and ct.fec_cancelacion = d.fecha))
      AND d.COD_MONEDA <> v_mon_local
      AND C.COD_PERSONA = CC.COD_PERSONA
      AND MO.COD_MODULO = CT.COD_MODULO
      AND MO.COD_MODALIDAD = CT.COD_MODALIDAD
      AND (v_usu_mig_excluir is null or ct.usu_insercion <> v_usu_mig_excluir)
      AND EXISTS (SELECT 0
                        FROM GE_TIP_ASIENTOS S, GE_TRANSACCIONES T
                       WHERE T.COD_MODULO = CT.COD_MODULO
                         AND T.COD_MODALIDAD = CT.COD_MODALIDAD
                         AND T.COD_TRANSACCION = 901
                         AND T.COD_TIP_ASIENTO = S.COD_TIP_ASIENTO
                         AND S.COD_MONEDA       = CT.COD_MONEDA
                         AND SUBSTR(S.COD_RUBRO,14,2) not in ('99','98')
                         AND (S.COD_SEC_CONTABLE = C.COD_SEC_CONTABLE or cod_sec_contable is null)
                         AND (S.IND_RESIDENTE    = C.RESIDENTE      OR IND_RESIDENTE = 'X')
                         AND (S.est_cuenta       = d.estado         or nvl(S.est_cuenta,'X') = 'X')
                         AND (S.tip_cuenta       = ct.tipo     or nvl(S.tip_cuenta,'X') = 'X')
                         AND (S.tip_interes      = ct.tip_interes    or nvl(S.tip_interes,'X') = 'X')
                         AND (S.tip_renovacion   = nvl(ct.tip_renovacion,'A') or nvl(S.tip_renovacion,'X') = 'X')
                         AND (S.cat_automatica   = d.categoria or nvl(S.cat_automatica,-1) = -1)
                         )
      AND PC.CAN_DIAS = (select min(CAN_DIAS)
                                from GE_PLZ_CONTABLES
                               where CAN_DIAS >= (CT.FEC_VENCIMIENTO-CT.FEC_INICIO))
     GROUP BY ct.COD_MODALIDAD,ct.cod_oficina,d.COD_MONEDA
     HAVING SUM(MTO_DEV_ACTUAL) <> 0;

BEGIN
   v_usu_mig_excluir := fug_obt_pardinamico('COD_USU_MIG_EXCLUIR');
   --
   select cod_tip_ope_bcp
     into v_cod_tip_ope_bcp
     from lc_tip_operaciones
    where cod_tip_operacion = v_cod_tip_operacion;

   IF CUR_DATOS%ISOPEN THEN
      CLOSE CUR_DATOS;
   END IF;
   OPEN CUR_DATOS;
   --v_hora := fug_ini_hora(SYSDATE,'HH24:MI:SS');
   v_hora := to_char(sysdate,'HH24:MI:SS');
   v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');

   LOOP
      FETCH CUR_DATOS INTO v_cod_modalidad,v_cod_oficina,v_cod_moneda,v_tot_interes;
      EXIT WHEN CUR_DATOS%NOTFOUND;
      -----------------------------------------------------------
      v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, 71, v_cod_moneda, v_cod_oficina)+1;
      prg_act_par_dinamico('NRO_RECIBO',7, 71, v_cod_moneda, v_cod_oficina, v_nro_operacion);

      v_cotizacion := pag_gen.FU_OBT_COTIZACION(v_cod_moneda,v_fec_actual);
      v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,v_cod_modalidad,v_mon_local);
      v_tot_mon_local := ROUND(NVL(v_cotizacion,0) * v_tot_interes,v_redondeo);
      --- genera movimiento ---
      --v_nro_secuencia       := 1;
      r_gmovi.cod_usuario   := user;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := 1; -- FIJO 1 para que tome los reportes de cambios
      r_gmovi.cod_modulo    := 7;
      r_gmovi.cod_modalidad := 71;
      r_gmovi.cod_oficina   := v_cod_oficina;
      r_gmovi.nro_cuenta    := null;
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.fec_valor     := v_fec_actual;
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.cod_tra_padre   := 901;
      r_gmovi.cod_transaccion := 901;
      r_gmovi.nro_documento := v_nro_operacion;
      r_gmovi.nro_documento2 := null;
      r_gmovi.monto         := v_tot_interes;
      r_gmovi.estado        := 'N';
      r_gmovi.cod_ofi_origen := v_cod_oficina;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      r_gmovi.cod_mod_padre := 7;
      r_gmovi.cod_mad_padre := 71;
      r_gmovi.concepto      := 'Deveng.Int. Cart.Act. Mod: '||v_cod_modalidad;
      r_gmovi.cotizacion    := v_cotizacion;
      r_gmovi.mto_equ_local := v_tot_mon_local;
      r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
      r_gmovi.COD_BCO_CENTRAL := v_cod_tip_ope_bcp;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --insertar movimientos en la Tabla de Posición de Cambios
      r_rpoca.cod_usuario   := user;
      r_rpoca.hora          := v_hora;
      r_rpoca.cod_modulo    := 7;
      r_rpoca.cod_modalidad := 71;
      r_rpoca.cod_oficina   := v_cod_oficina;
      r_rpoca.cod_moneda    := v_cod_moneda;
      r_rpoca.fecha         := v_fec_actual;
      r_rpoca.cod_tra_padre   := 901;
      r_rpoca.cod_transaccion := 901;
      r_rpoca.nro_documento := v_nro_operacion;
      r_rpoca.monto         := v_tot_interes;
      r_rpoca.cod_mod_padre := 7;
      r_rpoca.cod_mad_padre := 71;
      r_rpoca.concepto      := 'Deveng.Int. Cart.Act. Mod: '||v_cod_modalidad;
      g_cod_modalidad       := v_cod_modalidad;
      r_rpoca.cotizacion    := v_cotizacion;
      r_rpoca.mto_equ_local := v_tot_mon_local;
      r_rpoca.cod_tip_ope_cambio := v_cod_tip_operacion;
      r_rpoca.COD_BCO_CENTRAL := v_cod_tip_ope_bcp;
      r_rpoca.referencia      := 'COM_DEV_PRESTAMOS';
      pal_cie.pr_ins_bol_automaticas(r_rpoca);

      --- genera movimiento x persona, para listados ---
      --v_nro_secuencia       := 1;
      r_gmovi.cod_usuario   := user;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := 2; -- FIJO para que tome los reportes de cambios
      r_gmovi.cod_modulo    := 7;
      r_gmovi.cod_modalidad := 70;
      r_gmovi.cod_oficina   := v_cod_oficina;
      r_gmovi.nro_cuenta    := null;
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.fec_valor     := v_fec_actual;
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.cod_tra_padre   := 901;
      r_gmovi.cod_transaccion := 760;
      r_gmovi.nro_documento := v_nro_operacion;
      r_gmovi.nro_documento2 := LF_OBT_PER_ENTIDAD;
      r_gmovi.monto         := 0;
      r_gmovi.estado        := 'N';
      r_gmovi.cod_ofi_origen := v_cod_oficina;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      r_gmovi.cod_mod_padre := 7;
      r_gmovi.cod_mad_padre := 71;
      r_gmovi.concepto      := 'Deveng.Int. Cart.Act. Mod: '||v_cod_modalidad;
      r_gmovi.cotizacion    := null;
      r_gmovi.mto_equ_local := null;
      r_gmovi.cod_tip_ope_cambio := null;
      r_gmovi.COD_BCO_CENTRAL    := v_cod_tip_ope_bcp;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
       v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');
      --actualizar posicion
      UPDATE LC_POSICIONES SET
             MTO_COM_NEF_ACT = NVL(MTO_COM_NEF_ACT,0) + v_tot_interes,
             MTO_COM_NEF_LOC = NVL(MTO_COM_NEF_LOC,0) + v_tot_mon_local
       WHERE COD_TIP_OPE_BCP = v_cod_tip_ope_bcp
         AND COD_MONEDA = v_cod_moneda
         AND COD_OFI_CAMBIO = PAL_CAM.FU_OBT_OFI_CAMBIO(v_cod_oficina) ;
      --insertar posicion si no existe
      IF SQL%NOTFOUND THEN
         INSERT INTO LC_POSICIONES
             (COD_MONEDA,COD_TIP_OPE_BCP,COD_OFI_CAMBIO,
              MTO_COM_NEF_ACT,MTO_COM_NEF_LOC)
         VALUES
             (v_cod_moneda, v_cod_tip_ope_bcp,PAL_CAM.FU_OBT_OFI_CAMBIO(v_cod_oficina),
              v_tot_interes,v_tot_mon_local);
      END IF;
   END LOOP;
   IF CUR_DATOS%ISOPEN THEN
      CLOSE CUR_DATOS;
   END IF;
END;

/*Proceso que registra movimientos automaticos de venta por operaciones diarias
en moneda extranjera. Se correra en el cierre */
PROCEDURE PR_PRO_VENTAS IS

v_fec_actual        date := pag_cal.fu_obt_fec_actual(7); --fecha de hoy
v_cod_modalidad     NUMBER(04);
v_cod_modulo        NUMBER(04);
v_des_modulo        ba_modulos.descripcion%type;
v_cod_oficina       NUMBER(03);
v_cod_moneda        varchar2(03);
v_monto             NUMBER := 0;
v_hora              varchar2(08);
v_tot_mon_local     NUMBER;
v_cotizacion        ge_cotizaciones.val_conversion%type;
v_cod_tip_operacion lc_tip_operaciones.cod_tip_operacion%type := 31; -- fijo venta cuenta contable
v_cod_tip_ope_bcp   lc_tip_operaciones.cod_tip_ope_bcp%type;
r_gmovi             ge_movimientos%rowtype;
r_rpoca             lc_bol_automaticos_res%rowtype;
v_referencia        lc_bol_automaticos_res.referencia%type;
--v_nro_secuencia     ge_movimientos.nro_secuencia%type :=0;
v_mon_local         ba_monedas.cod_moneda%type :=  pag_gen.fu_obt_mon_local;
v_nro_operacion     ge_movimientos.nro_documento%type;
v_concepto          ge_movimientos.concepto%type;
v_redondeo          number(5);

CURSOR CUR_DATOS IS
    SELECT COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO,
           SUM(NVL(MONTO,0)), 'VTA_OPE_GEN_OTROS'
      FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       and a.cod_modulo NOT IN (4,6)
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'D'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
     GROUP BY COD_MONEDA,a.COD_MODULO,cod_oficina
union
     SELECT COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO,
           SUM(NVL(MONTO,0)), 'VTA_OPE_CTE_PREVISION'
      FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       and a.cod_modulo = 4
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Excluye Grupo de TransaccioNES DE Compra de Previsiones--
       and exists (select 1 from ge_gru_transacciones_det x
                    where x.cod_gru_transaccion = 301
                      and x.cod_transaccion = a.cod_transaccion
                      and x.cod_modulo = a.cod_modulo
                      and x.cod_modalidad = a.cod_modalidad)
       -----------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'D'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
     GROUP BY COD_MONEDA,a.COD_MODULO,cod_oficina
   union
   SELECT COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO,
           SUM(NVL(MONTO,0)), 'VTA_OPE_CTE_OTROS'
      FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       and a.cod_modulo = 4
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Excluye Grupo de TransaccioNES DE Compra de Previsiones--
       and not exists (select 1 from ge_gru_transacciones_det x
                        where x.cod_gru_transaccion = 301
                          and x.cod_transaccion = a.cod_transaccion
                          and x.cod_modulo = a.cod_modulo
                          and x.cod_modalidad = a.cod_modalidad)
       -----------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'D'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
     GROUP BY COD_MONEDA,a.COD_MODULO,cod_oficina
     UNION
     SELECT COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO,
           SUM(NVL(MONTO,0)), 'VTA_OPE_PRE_PREVISION'
      FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       and a.cod_modulo = 6
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Excluye Grupo de TransaccioNES DE Compra de Previsiones--
       and exists (select 1 from ge_gru_transacciones_det x
                    where x.cod_gru_transaccion = 301
                      and x.cod_transaccion = a.cod_transaccion
                      and x.cod_modulo = a.cod_modulo
                      and x.cod_modalidad = a.cod_modalidad)
       -----------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'D'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
     GROUP BY COD_MONEDA,a.COD_MODULO,cod_oficina
   union
   SELECT COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO,
           SUM(NVL(MONTO,0)), 'VTA_OPE_PRE_OTROS'
      FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       and a.cod_modulo = 6
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Excluye Grupo de TransaccioNES DE Compra de Previsiones--
       and not exists (select 1 from ge_gru_transacciones_det x
                        where x.cod_gru_transaccion = 301
                          and x.cod_transaccion = a.cod_transaccion
                          and x.cod_modulo = a.cod_modulo
                          and x.cod_modalidad = a.cod_modalidad)
       -----------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'D'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
     GROUP BY COD_MONEDA,a.COD_MODULO,cod_oficina
--Ingrid Larraín: 01/09/2011: Para que tome los movimientos generados por Apuntes masivos (Copia de lo de RI de Compras)
union
  SELECT A.COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO,
           SUM(NVL(MONTO,0)), 'VTA_APU_MASIVO'
      FROM CB_RUBROS X, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE <> 7
       AND A.COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND A.TIP_MOV_RUBRO= 'D'
       AND X.COD_RUBRO(+) = A.COD_RUBRO
       AND ((SUBSTR(A.COD_RUBRO,-2,2) IN ('98','99')) OR
           (X.COD_MONEDA = v_mon_local) or
            (SUBSTR(A.COD_RUBRO,1,1) IN ('6','7')))
     GROUP BY A.COD_MONEDA,a.COD_MODULO,A.cod_oficina
--- Ingrid Larraín: 16/09/2011: Solo para apuntes masivos contables, en base a definición de Agustín Meza
--- Preparado para cuando existan otras funcionalidades similares se puede poner la transaccion padre
--- Solo para cuando los rubros de ganancias o perdidas son en guaranies o cuando es intermoneda Activo y Pasivo
union
  SELECT A.COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO,
           SUM(NVL(MONTO,0)), 'VTA_APU_INTERMONEDA'
      FROM CB_RUBROS X, ge_movimientos a
     WHERE a.COD_MOD_PADRE IN(1, 2)
       AND A.COD_TRA_PADRE=100
       AND A.COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND A.TIP_MOV_RUBRO= 'C' --- Ajuste realizado por ICL 13/01/2012 en base a Incidencia reportada por Victor P. ya que la parte del crédito debe ser la moneda local
       AND A.Cod_Rubro is not null
       AND SUBSTR(a.COD_RUBRO,1,1) IN ('1','2')
       AND X.COD_RUBRO = A.COD_RUBRO
       and exists(select c.* from ge_movimientos c
                   where c.hora=a.hora
                   and c.fecha=a.fecha
                   and c.cod_usuario=a.cod_usuario
                   and c.cod_rubro is not null
                   and c.cod_rubro <> a.cod_rubro
                   AND  (
                         (SUBSTR(c.COD_RUBRO,14,2) IN ('98','99')
                      AND SUBSTR(c.COD_RUBRO,1,1) IN ('6','7'))
                      OR (
                          SUBSTR(c.COD_RUBRO,14,2) IN ('98','99')
                      AND SUBSTR(c.COD_RUBRO,1,1) IN ('1','2')
                          )
                        )
                   )
     GROUP BY A.COD_MONEDA,a.COD_MODULO,A.cod_oficina
   union
   --SDRES4COVI-81 - Resolución 4 - Previsiones Constitución y Diferimiento Productos RES04   
   SELECT COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO,
           SUM(NVL(MONTO,0)), 'VTA_OPE_PRE_RES4'
      FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       and a.cod_modulo = 6
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Incluye Grupo de Transacciones de Compra de Previsiones Resolución 4--
       and exists (select 1 from ge_gru_transacciones_det x
                        where x.cod_gru_transaccion = 400
                          and x.cod_transaccion = a.cod_transaccion
                          and x.cod_modulo = a.cod_modulo
                          and x.cod_modalidad = a.cod_modalidad)
       -----------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'D'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) = '1'))
                   )
     GROUP BY COD_MONEDA,a.COD_MODULO,cod_oficina;
BEGIN
  IF CUR_DATOS%ISOPEN THEN
      CLOSE CUR_DATOS;
  END IF;
  OPEN CUR_DATOS;
  --v_hora := fug_ini_hora(SYSDATE,'HH24:MI:SS');
  v_hora := to_char(sysdate,'HH24:MI:SS');
  v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');

  LOOP
      FETCH CUR_DATOS
       INTO v_cod_moneda,v_cod_modulo,v_cod_oficina,v_monto,v_referencia;
      EXIT WHEN CUR_DATOS%NOTFOUND;
      -----------------------------------------------------------
      Select lower(substr(DESCRIPCION,1,9))
        into v_des_modulo
        from BA_MODULOS
       Where COD_MODULO = v_cod_modulo;
      --como tambien entran las reversiones, esto es en caso de q estas superen a las operaciones
      IF v_monto >= 0 THEN
         v_cod_modalidad := 72;
         v_cod_tip_operacion := 31;
         v_concepto := 'Venta Div. p/Oper.'||v_des_modulo;
      ELSE
         v_cod_modalidad := 71;
         v_cod_tip_operacion := 17;
         v_concepto := 'Compra Div. p/Oper.'||v_des_modulo;
      END IF;
      -----------------------------------------------------------
      BEGIN
       SELECT COD_TIP_OPE_BCP
         INTO v_cod_tip_ope_bcp
         FROM LC_TIP_OPERACIONES
        WHERE LC_TIP_OPERACIONES.COD_TIP_OPERACION = v_cod_tip_operacion;
      EXCEPTION
       WHEN OTHERS THEN
         IF v_cod_tip_operacion = 31 THEN
            v_cod_tip_ope_bcp := 'B27';
         ELSE
            v_cod_tip_ope_bcp := 'A19';
         END IF;
      END;
      -----------------------------------------------------------
      v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, v_cod_modalidad, v_cod_moneda, v_cod_oficina)+1;
      prg_act_par_dinamico('NRO_RECIBO',7, v_cod_modalidad, v_cod_moneda, v_cod_oficina, v_nro_operacion);

      v_cotizacion := pag_gen.FU_OBT_COTIZACION(v_cod_moneda,v_fec_actual);
      v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,v_cod_modalidad,v_mon_local);
      v_tot_mon_local := ROUND(NVL(v_cotizacion,0) * v_monto,v_redondeo);

      --- genera movimiento ---
      --v_nro_secuencia       := 1;
      r_gmovi.cod_usuario   := user;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := 1; -- FIJO 1 para que tome los reportes de cambios
      r_gmovi.cod_modulo    := 7;
      r_gmovi.cod_modalidad := v_cod_modalidad;
      r_gmovi.cod_oficina   := v_cod_oficina;
      r_gmovi.nro_cuenta    := null;
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.fec_valor     := v_fec_actual;
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.cod_tra_padre   := 942;
      r_gmovi.cod_transaccion := 942;
      r_gmovi.nro_documento := v_nro_operacion;
      r_gmovi.nro_documento2 := null;
      r_gmovi.monto         := abs(v_monto);
      r_gmovi.estado        := 'N';
      r_gmovi.cod_ofi_origen := v_cod_oficina;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      r_gmovi.cod_mod_padre := 7;
      r_gmovi.cod_mad_padre := v_cod_modalidad;
      r_gmovi.concepto      := v_concepto ||' en '||v_cod_moneda;
      r_gmovi.cotizacion    := v_cotizacion;
      r_gmovi.mto_equ_local := abs(v_tot_mon_local);
      r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
      r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --insertar movimientos en la Tabla de Posición de Cambios
      r_rpoca.cod_usuario   := user;
      r_rpoca.hora          := v_hora;
      r_rpoca.cod_modulo    := 7;
      g_cod_modulo          := v_cod_modulo;
      r_rpoca.cod_modalidad := v_cod_modalidad;
      r_rpoca.cod_oficina   := v_cod_oficina;
      r_rpoca.cod_moneda    := v_cod_moneda;
      r_rpoca.fecha         := v_fec_actual;
      r_rpoca.cod_tra_padre   := 942;
      r_rpoca.cod_transaccion := 942;
      r_rpoca.nro_documento := v_nro_operacion;
      r_rpoca.monto         := abs(v_monto);
      r_rpoca.cod_mod_padre := 7;
      r_rpoca.cod_mad_padre := v_cod_modalidad;
      r_rpoca.concepto      := v_concepto ||' en '||v_cod_moneda;
      r_rpoca.cotizacion    := v_cotizacion;
      r_rpoca.mto_equ_local := abs(v_tot_mon_local);
      r_rpoca.cod_tip_ope_cambio := v_cod_tip_operacion;
      r_rpoca.cod_bco_central    := v_cod_tip_ope_bcp;
      r_rpoca.referencia    := v_referencia;
      pal_cie.pr_ins_bol_automaticas(r_rpoca);

      --- genera movimiento x persona, para listados ---
      --v_nro_secuencia       := 1;
      r_gmovi.cod_usuario   := user;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := 2; -- FIJO para que tome los reportes de cambios
      r_gmovi.cod_modulo    := 7;
      r_gmovi.cod_modalidad := 70;
      r_gmovi.cod_oficina   := v_cod_oficina;
      r_gmovi.nro_cuenta    := null;
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.fec_valor     := v_fec_actual;
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.cod_tra_padre   := 942;
      r_gmovi.cod_transaccion := 760;
      r_gmovi.nro_documento := v_nro_operacion;
      r_gmovi.nro_documento2 := LF_OBT_PER_ENTIDAD;
      r_gmovi.monto         := 0;
      r_gmovi.estado        := 'N';
      r_gmovi.cod_ofi_origen := v_cod_oficina;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      r_gmovi.cod_mod_padre := 7;
      r_gmovi.cod_mad_padre := v_cod_modalidad;
      r_gmovi.concepto      := v_concepto ||' en '||v_cod_moneda;
      r_gmovi.cotizacion    := null;
      r_gmovi.mto_equ_local := null;
      r_gmovi.cod_tip_ope_cambio := null;
      r_gmovi.COD_BCO_CENTRAL    := v_cod_tip_ope_bcp;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      --wa:para pk
      v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');

      IF v_cod_modalidad = 72 THEN  /* ES UNA VENTA */
         --actualiza la posicion
         UPDATE LC_POSICIONES SET
                MTO_VTA_NEF_ACT = NVL(MTO_VTA_NEF_ACT,0) + v_monto,
                MTO_VTA_NEF_LOC = NVL(MTO_VTA_NEF_LOC,0) + v_tot_mon_local
         WHERE COD_TIP_OPE_BCP = v_cod_tip_ope_bcp
           AND COD_MONEDA = v_cod_moneda
           AND COD_OFI_CAMBIO = pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina);
        --inserta posicion si no existe
        IF SQL%NOTFOUND THEN
           INSERT INTO LC_POSICIONES
               (COD_MONEDA, COD_TIP_OPE_BCP, COD_OFI_CAMBIO,
                MTO_VTA_NEF_ACT, MTO_VTA_NEF_LOC)
           VALUES
               (v_cod_moneda, v_cod_tip_ope_bcp,
                pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina), v_monto,v_tot_mon_local);
        END IF;
      ELSE --es una compra
        --actualiza la posicion
        UPDATE LC_POSICIONES SET
               MTO_COM_NEF_ACT = NVL(MTO_COM_NEF_ACT,0) + ABS(v_monto),
               MTO_COM_NEF_LOC = NVL(MTO_COM_NEF_LOC,0) + ABS(v_tot_mon_local)
         WHERE COD_TIP_OPE_BCP = v_cod_tip_ope_bcp
           AND COD_MONEDA = v_cod_moneda
           AND COD_OFI_CAMBIO = pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina);
        --inserta posicion si no existe
        IF SQL%NOTFOUND THEN
           INSERT INTO LC_POSICIONES
               (COD_MONEDA, COD_TIP_OPE_BCP, COD_OFI_CAMBIO,
                MTO_COM_NEF_ACT, MTO_COM_NEF_LOC)
           VALUES
               (v_cod_moneda, v_cod_tip_ope_bcp,
                pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina), ABS(v_monto), ABS(v_tot_mon_local));
        END IF;
      END IF;
  END LOOP;
  IF CUR_DATOS%ISOPEN THEN
     CLOSE CUR_DATOS;
  END IF;
  -- Llamo al proceso que realiza los movimientos automaticos de ventas por Clientes
  pr_pro_vta_clientes;
END;

/*Proceso que registra movimientos automaticos de compra por operaciones diarias
en moneda extranjera. Se correra en el cierre */
PROCEDURE PR_PRO_COMPRAS IS

v_fec_actual        date := pag_cal.fu_obt_fec_actual(7); --fecha de hoy
v_cod_modalidad     NUMBER(04);
v_cod_modulo        NUMBER(04);
v_des_modulo        ba_modulos.descripcion%type;
v_cod_oficina       NUMBER(03);
v_cod_moneda        varchar2(03);
v_monto             NUMBER := 0;
v_hora              varchar2(08);
v_tot_mon_local     NUMBER;
v_cotizacion        ge_cotizaciones.val_conversion%type;
v_cod_tip_operacion lc_tip_operaciones.cod_tip_operacion%type := 17; -- fijo compra cuenta contable
v_cod_tip_ope_bcp   lc_tip_operaciones.cod_tip_ope_bcp%type;
r_gmovi             ge_movimientos%rowtype;
r_rpoca             lc_bol_automaticos_res%rowtype;
v_referencia        lc_bol_automaticos_res.referencia%type;
v_mon_local         ba_monedas.cod_moneda%type :=  pag_gen.fu_obt_mon_local;
v_nro_operacion     ge_movimientos.nro_documento%type;
--v_concepto          ge_movimientos.concepto%type;
v_redondeo          number(5);

CURSOR CUR_DATOS IS
    SELECT COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO,
           SUM(NVL(MONTO,0)), 'COM_OPE_PRE_OTROS'
      FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND A.COD_MODULO = 6 /*DYDMR2255*/
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Excluye Grupo de TransaccioNES DE Compra de Previsiones--
       and not exists (select 1 from ge_gru_transacciones_det x
                        where x.cod_gru_transaccion = 300
                          and x.cod_transaccion = a.cod_transaccion
                          and x.cod_modulo = a.cod_modulo
                          and x.cod_modalidad = a.cod_modalidad)
       --------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'C'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND (A.EST_CUENTA = C.EST_CUENTA OR C.EST_CUENTA IS NULL) /*DYDMR2255*/
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
     GROUP BY COD_MONEDA,a.COD_MODULO,cod_oficina
     UNION
     --Previsiones de Prestamos--
     SELECT COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO,
           SUM(NVL(MONTO,0)), 'COM_OPE_PRE_PREVISION'
      FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND A.COD_MODULO = 6 /*DYDMR2255*/
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Incluye Grupo de TransaccioNES DE Compra de Previsiones--
       and exists (select 1 from ge_gru_transacciones_det x
                    where x.cod_gru_transaccion = 300
                      and x.cod_transaccion = a.cod_transaccion
                      and x.cod_modulo = a.cod_modulo
                      and x.cod_modalidad = a.cod_modalidad)
       --------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'C'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND (A.EST_CUENTA = C.EST_CUENTA OR C.EST_CUENTA IS NULL) /*DYDMR2255*/
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
     GROUP BY COD_MONEDA,a.COD_MODULO,cod_oficina
     ------------DYDMR-2255 04/09/2015 FM--------------------------
     UNION
     SELECT COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO,
           SUM(NVL(MONTO,0)), 'COM_OPE_GEN_OTROS'
      FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND A.COD_MODULO NOT IN (4,6) /*DYDMR2255*/
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'C'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
     GROUP BY COD_MONEDA,a.COD_MODULO,cod_oficina

UNION
     SELECT COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO,
           SUM(NVL(MONTO,0)), 'COM_OPE_CTE_PREVISION'
      FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND A.COD_MODULO = 4 /*DYDMR2255*/
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Excluye Grupo de TransaccioNES DE Compra de Previsiones--
       and exists (select 1 from ge_gru_transacciones_det x
                    where x.cod_gru_transaccion = 300
                      and x.cod_transaccion = a.cod_transaccion
                      and x.cod_modulo = a.cod_modulo
                      and x.cod_modalidad = a.cod_modalidad)
       --------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'C'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
     GROUP BY COD_MONEDA,a.COD_MODULO,cod_oficina
 UNION
     SELECT COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO,
           SUM(NVL(MONTO,0)), 'COM_OPE_CTE_OTROS'
      FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND A.COD_MODULO = 4 /*DYDMR2255*/
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Excluye Grupo de TransaccioNES DE Compra de Previsiones--
       and not exists (select 1 from ge_gru_transacciones_det x
                        where x.cod_gru_transaccion = 300
                          and x.cod_transaccion = a.cod_transaccion
                          and x.cod_modulo = a.cod_modulo
                          and x.cod_modalidad = a.cod_modalidad)
       --------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'C'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
     GROUP BY COD_MONEDA,a.COD_MODULO,cod_oficina

--RI: 23/11/2010: Para que tome los movimientos generados por las Previsiones
--  Genericas.
union
  SELECT A.COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO,
           SUM(NVL(MONTO,0)), 'COM_PRE_GENERICA'
      FROM CB_RUBROS X, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE <> 7
       AND A.COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND A.TIP_MOV_RUBRO= 'C'
       AND X.COD_RUBRO(+) = A.COD_RUBRO
       AND ((SUBSTR(A.COD_RUBRO,-2,2) IN ('98','99')) OR
           (X.COD_MONEDA = v_mon_local) or
            (SUBSTR(A.COD_RUBRO,1,1) IN ('6','7')))
     GROUP BY A.COD_MONEDA,a.COD_MODULO,A.cod_oficina
--- Ingrid Larraín: 16/09/2011: Solo para apuntes masivos contables, en base a definición de Agustín Meza
--- Preparado para cuando existan otras funcionalidades similares se puede poner la transaccion padre
--- Solo para cuando los rubros de ganancias o perdidas son en guaranies o cuando es intermoneda Activo y Pasivo
union
  SELECT A.COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO,
           SUM(NVL(MONTO,0)), 'COM_APU_MASIVO'
      FROM CB_RUBROS X, ge_movimientos a
     WHERE a.COD_MOD_PADRE IN(1, 2)
       AND A.COD_TRA_PADRE=100
       AND A.COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND A.TIP_MOV_RUBRO= 'D' --- Ajuste realizado por ICL 13/01/2012 en base a Incidencia reportada por Victor P. ya que la parte del débito debe ser la moneda local
       AND A.Cod_Rubro is not null
       AND X.COD_RUBRO = A.COD_RUBRO
       AND SUBSTR(a.COD_RUBRO,1,1) IN ('1','2')
       and exists(select c.* from ge_movimientos c
                   where c.hora=a.hora
                   and c.fecha=a.fecha
                   and c.cod_usuario=a.cod_usuario
                   and c.cod_rubro is not null
                   and c.cod_rubro <> a.cod_rubro
                   AND  (
                         (SUBSTR(c.COD_RUBRO,14,2) IN ('98','99')
                      AND SUBSTR(c.COD_RUBRO,1,1) IN ('6','7'))
                      OR (
                          SUBSTR(c.COD_RUBRO,14,2) IN ('98','99')
                      AND SUBSTR(c.COD_RUBRO,1,1) IN ('1','2')
                          )
                        )
                   )
     GROUP BY A.COD_MONEDA,a.COD_MODULO,A.cod_oficina
union
     --SDRES4COVI-81 - Resolución 4 - Previsiones Constitución y Diferimiento Productos RES04
     SELECT COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO,
           SUM(NVL(MONTO,0)), 'COM_OPE_PRE_RES4'
      FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND A.COD_MODULO = 6
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Incluye Grupo de Transacciones de Compra de Previsiones Resolución 4--
       and exists (select 1 from ge_gru_transacciones_det x
                        where x.cod_gru_transaccion = 400
                          and x.cod_transaccion = a.cod_transaccion
                          and x.cod_modulo = a.cod_modulo
                          and x.cod_modalidad = a.cod_modalidad)
       --------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'C'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) = '1'))
                   )
     GROUP BY COD_MONEDA,a.COD_MODULO,cod_oficina
UNION
    --SDL6380INR-1 - Impuesto a la renta a no residentes - INR
     SELECT COD_MONEDA,a.COD_MODULO,cod_oficina COD_OFI_CAMBIO,
           SUM(NVL(MONTO,0)), 'COM_MOV_RET_INR'
      FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE IN (3,9)
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND A.COD_MODULO IN (3, 4)
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       AND b.cod_transaccion = 9603
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'C'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) = '1'))
                   )
     GROUP BY COD_MONEDA,a.COD_MODULO,cod_oficina;
BEGIN
  BEGIN
    SELECT COD_TIP_OPE_BCP
      INTO v_cod_tip_ope_bcp
      FROM LC_TIP_OPERACIONES
     WHERE LC_TIP_OPERACIONES.COD_TIP_OPERACION = v_cod_tip_operacion;
  EXCEPTION
    WHEN OTHERS THEN v_cod_tip_ope_bcp := 'A19';
  END;
  ----------------------------------------------------------------
  IF CUR_DATOS%ISOPEN THEN
      CLOSE CUR_DATOS;
  END IF;
  OPEN CUR_DATOS;
  --v_hora := fug_ini_hora(SYSDATE,'HH24:MI:SS');
  v_hora := to_char(sysdate,'HH24:MI:SS');
  v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');

  LOOP
      FETCH CUR_DATOS
      INTO v_cod_moneda,v_cod_modulo,v_cod_oficina,v_monto,v_referencia;
      EXIT WHEN CUR_DATOS%NOTFOUND;

      Select lower(substr(DESCRIPCION,1,9))
        into v_des_modulo
        from BA_MODULOS
       Where COD_MODULO = v_cod_modulo;

      -----------------------------------------------------------
      v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, 71, v_cod_moneda, v_cod_oficina)+1;
      prg_act_par_dinamico('NRO_RECIBO',7, 71, v_cod_moneda, v_cod_oficina, v_nro_operacion);

      v_cotizacion := pag_gen.FU_OBT_COTIZACION(v_cod_moneda,v_fec_actual);
      v_redondeo   := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,v_cod_modalidad,v_mon_local);
      v_tot_mon_local := ROUND(NVL(v_cotizacion,0) * v_monto,v_redondeo);
      --- genera movimiento ---
      r_gmovi.cod_usuario   := user;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := 1; -- FIJO 1 para que tome los reportes de cambios
      r_gmovi.cod_modulo    := 7;
      r_gmovi.cod_modalidad := 71;
      r_gmovi.cod_oficina   := v_cod_oficina;
      r_gmovi.nro_cuenta    := null;
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.fec_valor     := v_fec_actual;
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.cod_tra_padre   := 942;
      r_gmovi.cod_transaccion := 942;
      r_gmovi.nro_documento := v_nro_operacion;
      r_gmovi.nro_documento2 := null;
      r_gmovi.monto         := v_monto;
      r_gmovi.estado        := 'N';
      r_gmovi.cod_ofi_origen := v_cod_oficina;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      r_gmovi.cod_mod_padre := 7;
      r_gmovi.cod_mad_padre := 71;
      r_gmovi.concepto      := 'Compra Div. p/Oper.'||v_des_modulo||' en '||v_cod_moneda;
      r_gmovi.cotizacion    := v_cotizacion;
      r_gmovi.mto_equ_local := v_tot_mon_local;
      r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
      r_gmovi.COD_BCO_CENTRAL    := v_cod_tip_ope_bcp;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --insertar movimientos en la Tabla de Posición de Cambios
      r_rpoca.cod_usuario   := user;
      r_rpoca.hora          := v_hora;
      r_rpoca.cod_modulo    := 7;
      g_cod_modulo          := v_cod_modulo;
      r_rpoca.cod_modalidad := 71;
      r_rpoca.cod_oficina   := v_cod_oficina;
      r_rpoca.cod_moneda    := v_cod_moneda;
      r_rpoca.fecha         := v_fec_actual;
      r_rpoca.cod_tra_padre   := 942;
      r_rpoca.cod_transaccion := 942;
      r_rpoca.nro_documento := v_nro_operacion;
      r_rpoca.monto         := v_monto;
      r_rpoca.cod_mod_padre := 7;
      r_rpoca.cod_mad_padre := 71;
      r_rpoca.concepto      := 'Compra Div. p/Oper.'||v_des_modulo||' en '||v_cod_moneda;
      r_rpoca.cotizacion    := v_cotizacion;
      r_rpoca.mto_equ_local := v_tot_mon_local;
      r_rpoca.cod_tip_ope_cambio := v_cod_tip_operacion;
      r_rpoca.COD_BCO_CENTRAL    := v_cod_tip_ope_bcp;
      r_rpoca.referencia    := v_referencia;
      pal_cie.pr_ins_bol_automaticas(r_rpoca);

      --- genera movimiento x persona, para listados ---
      r_gmovi.cod_usuario   := user;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := 2; -- FIJO para que tome los reportes de cambios
      r_gmovi.cod_modulo    := 7;
      r_gmovi.cod_modalidad := 70;
      r_gmovi.cod_oficina   := v_cod_oficina;
      r_gmovi.nro_cuenta    := null;
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.fec_valor     := v_fec_actual;
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.cod_tra_padre   := 942;
      r_gmovi.cod_transaccion := 760;
      r_gmovi.nro_documento := v_nro_operacion;
      r_gmovi.nro_documento2 := LF_OBT_PER_ENTIDAD;
      r_gmovi.monto         := 0;
      r_gmovi.estado        := 'N';
      r_gmovi.cod_ofi_origen := v_cod_oficina;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      r_gmovi.cod_mod_padre := 7;
      r_gmovi.cod_mad_padre := 71;
      r_gmovi.concepto      := 'Compra Div. p/Oper.'||v_des_modulo||' en '||v_cod_moneda;
      r_gmovi.cotizacion    := null;
      r_gmovi.mto_equ_local := null;
      r_gmovi.cod_tip_ope_cambio := null;
      r_gmovi.COD_BCO_CENTRAL    := v_cod_tip_ope_bcp;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --v_hora := pag_gen.FU_OBT_SIG_SEGUNDO(v_hora);
      --wa:para pk
       v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');
      --actualiza la posicion
      UPDATE LC_POSICIONES SET
             MTO_COM_NEF_ACT = NVL(MTO_COM_NEF_ACT,0) + v_monto,
             MTO_COM_NEF_LOC = NVL(MTO_COM_NEF_LOC,0) + v_tot_mon_local
       WHERE COD_TIP_OPE_BCP = v_cod_tip_ope_bcp
         AND COD_MONEDA = v_cod_moneda
         AND COD_OFI_CAMBIO = pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina);
      --inserta posicion si no existe
      IF SQL%NOTFOUND THEN
           INSERT INTO LC_POSICIONES
               (COD_MONEDA, COD_TIP_OPE_BCP, COD_OFI_CAMBIO,
                MTO_COM_NEF_ACT, MTO_COM_NEF_LOC)
           VALUES
               (v_cod_moneda, v_cod_tip_ope_bcp,
                pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina), ABS(v_monto), ABS(v_tot_mon_local));
      END IF;
  END LOOP;
  IF CUR_DATOS%ISOPEN THEN
     CLOSE CUR_DATOS;
  END IF;
  -- Llamo al proceso que realiza los movimientos automaticos de compras por Clientes
  pr_pro_com_clientes;
END;

/*Proceso que registra movimientos automaticos de venta por operaciones diarias
por Clientes en moneda extranjera. Es llamado desde PR_PRO_VENTAS - AP 741 - SDC */
PROCEDURE PR_PRO_VTA_CLIENTES IS

v_fec_actual        date := pag_cal.fu_obt_fec_actual(7); --fecha de hoy
v_cod_modalidad     NUMBER(04);
v_cod_modulo        NUMBER(04);
v_des_modulo        ba_modulos.descripcion%type;
v_cod_oficina       NUMBER(03);
v_cod_moneda        varchar2(03);
v_monto             NUMBER := 0;
v_hora              varchar2(08);
v_tot_mon_local     NUMBER;
v_cotizacion        ge_cotizaciones.val_conversion%type;
v_cod_tip_operacion lc_tip_operaciones.cod_tip_operacion%type := 31; -- fijo venta cuenta contable
v_cod_tip_ope_bcp   lc_tip_operaciones.cod_tip_ope_bcp%type;
r_gmovi             ge_movimientos%rowtype;
r_rpoca             lc_bol_automaticos_res%rowtype;
v_referencia        lc_bol_automaticos_res.referencia%type;
v_mon_local         ba_monedas.cod_moneda%type :=  pag_gen.fu_obt_mon_local;
v_nro_operacion     ge_movimientos.nro_documento%type;
v_concepto          ge_movimientos.concepto%type;
v_redondeo          number(5);
v_cod_persona       ba_personas.cod_persona%type;
v_nro_cuenta        ge_cuentas.nro_cuenta%type;
v_cod_tra_padre     ge_movimientos.cod_tra_padre%type;
v_usu_hbank         ba_usuarios.cod_usuario%type := fug_obt_pardinamico('COD_USU_HOMEBANKING');
v_ind_inc_hbank     varchar2(1) := fug_obt_pardinamico ('IND_INC_HBANK');
cursor cur_datos is
     --- operaciones de compra y extracciones atm en el extranjero
   select b.cod_moneda, b.cod_modulo, b.cod_oficina, nvl(b.monto,0) monto,
          a.nro_cuenta, nvl(b.cotizacion, a.cotizacion) cotizacion, a.cod_tra_padre,
          '_ATM_EXTERIOR' referencia, a.nro_documento --DYDMR-3202
     from ge_movimientos b, ge_movimientos a
    where a.cod_mod_padre = 9
      and a.cod_tra_padre in (374,375,388,486)  -- COMPRA Y EXTRACCIONES EN EL EXTERIOR, Y TRANSF.HB
      and a.estado = 'N'
      and a.cod_transaccion = 503
      and a.monto <> 0
      and b.cod_mod_padre = 9
      and b.estado = 'N'
      and b.cod_transaccion = 602
      and b.fecha = a.fecha
      and b.cod_usuario = a.cod_usuario
      and b.hora = a.hora
      and b.nro_documento = a.nro_documento
      and b.cod_moneda <> a.cod_moneda
      and b.monto <> 0
      and b.cod_moneda <> v_mon_local
union all -- DYDMR-3381
   select b.cod_moneda, b.cod_modulo, b.cod_oficina, nvl(b.monto,0) monto,
          decode(a.cod_transaccion, 190, b.nro_cuenta, a.nro_cuenta) nro_cuenta,
          nvl(b.cotizacion, a.cotizacion) cotizacion, a.cod_tra_padre,
          '_SIPAP', decode(a.cod_transaccion, 190, b.nro_documento, a.nro_documento) nro_documento -- DYDMR-3202
     from ge_movimientos b, ge_movimientos a
    where a.cod_tra_padre in (302,303) -- SNP  -- CNFPRSIP-217 - Pago a Proveedores Nueva Transaccion --
      and a.estado = 'N'
      and a.cod_transaccion in (503, 190)
      and a.monto <> 0
      and b.cod_mad_padre = 455
      and b.estado = 'N'
      and b.cod_transaccion in (602, 196)
      and b.fecha = a.fecha
      and b.cod_usuario = a.cod_usuario
      and b.hora = a.hora
      and b.nro_documento = a.nro_documento
      and b.cod_moneda <> a.cod_moneda
      and b.monto <> 0
      and b.cod_moneda <> v_mon_local
      AND ( b.COD_USUARIO = v_usu_hbank
              and v_ind_inc_hbank = 'N' );  -- CANREQVAR-411 - Pago a Proveedores ITGF genera movimientos en linea --

BEGIN
  if cur_datos%isopen then
      close cur_datos;
  end if;
  open cur_datos;
  --v_hora := fug_ini_hora(sysdate,'HH24:MI:SS');
   v_hora := to_char(sysdate,'HH24:MI:SS');
   --wa:para pk
   v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');

  loop
      fetch cur_datos
       into v_cod_moneda,v_cod_modulo,v_cod_oficina,v_monto, v_nro_cuenta, v_cotizacion,
            v_cod_tra_padre,v_referencia, v_nro_operacion; --DYDMR-3202
      exit when cur_datos%notfound;
      -----------------------------------------------------------
      Select lower(substr(descripcion,1,9))
        into v_des_modulo
        from ba_modulos
       Where cod_modulo = v_cod_modulo;
      --como tambien entran las reversiones, esto es en caso de q estas superen a las operaciones
      IF v_monto >= 0 THEN
         v_cod_modalidad     := 72;
         v_cod_tip_operacion := 31;
         v_concepto          := 'Venta Div. p/Oper.'||v_des_modulo;
         v_referencia        := 'VTA'||v_referencia;
      ELSE
         v_cod_modalidad     := 71;
         v_cod_tip_operacion := 17;
         v_concepto          := 'Compra Div. p/Oper.'||v_des_modulo;
         v_referencia        := 'COM_REV'||v_referencia;
      END IF;
      -----------------------------------------------------------
      begin
       select cod_tip_ope_bcp
         into v_cod_tip_ope_bcp
         from lc_tip_operaciones
        where lc_tip_operaciones.cod_tip_operacion = v_cod_tip_operacion;
      exception
       when others then
         if v_cod_tip_operacion = 31 then
            v_cod_tip_ope_bcp := 'B27';
         else
            v_cod_tip_ope_bcp := 'A19';
         end if;
      end;
      -----------------------------------------------------------
      -- DYDMR-3202 el movimiento generado coincide en nro_documento con el movimiento original
      v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, v_cod_modalidad, v_cod_moneda, v_cod_oficina)+1;
      prg_act_par_dinamico('NRO_RECIBO',7, v_cod_modalidad, v_cod_moneda, v_cod_oficina, v_nro_operacion);
      if v_cod_tra_padre in (303, 388, 486, 302) then
         v_cotizacion := nvl(v_cotizacion, paw_bce.fu_obt_cotizacion(v_cod_moneda, 'V'));
      else
         -- DYDMR-10855 Diferencia de Factura - Extracto - NAF 05/2019
         -- si el movimiento original tiene valor cotización se utiliza el mismo valor
         v_cotizacion := nvl(v_cotizacion, pag_gen.fu_obt_cotizacion(v_cod_moneda,v_fec_actual));         
      end if;
      v_redondeo      := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,v_cod_modalidad,v_mon_local);
      v_tot_mon_local := round(nvl(v_cotizacion,0) * v_monto,v_redondeo);

      -- Obtiene el código de Persona
      if v_nro_cuenta is not null then
         v_cod_persona := fug_obt_cli_principal (v_nro_cuenta);
      else
         v_cod_persona := lf_obt_per_entidad;
      end if;
      --- genera movimiento ---
      r_gmovi.cod_usuario   := user;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := 1; -- FIJO 1 para que tome los reportes de cambios
      r_gmovi.cod_modulo    := 7;
      r_gmovi.cod_modalidad := v_cod_modalidad;
      r_gmovi.cod_oficina   := v_cod_oficina;
      r_gmovi.nro_cuenta    := null;
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.fec_valor     := v_fec_actual;
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.cod_tra_padre   := 942;
      r_gmovi.cod_transaccion := 942;
      r_gmovi.nro_documento   := v_nro_operacion;
      r_gmovi.nro_documento2  := null;
      r_gmovi.monto           := abs(v_monto);
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := v_cod_oficina;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      r_gmovi.cod_mod_padre := 7;
      r_gmovi.cod_mad_padre := v_cod_modalidad;
      r_gmovi.concepto      := v_concepto ||' en '||v_cod_moneda;
      r_gmovi.cotizacion    := v_cotizacion;
      r_gmovi.mto_equ_local := abs(v_tot_mon_local);
      r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
      r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
      r_gmovi.cod_persona   := v_cod_persona;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --insertar movimientos en la Tabla de Posición de Cambios
      r_rpoca.cod_usuario   := user;
      r_rpoca.hora          := v_hora;
      r_rpoca.cod_modulo    := 7;
      r_rpoca.cod_modalidad := v_cod_modalidad;
      r_rpoca.cod_oficina   := v_cod_oficina;
      r_rpoca.cod_moneda    := v_cod_moneda;
      r_rpoca.fecha         := v_fec_actual;
      r_rpoca.cod_tra_padre   := 942;
      r_rpoca.cod_transaccion := 942;
      r_rpoca.nro_documento   := v_nro_operacion;
      r_rpoca.monto           := abs(v_monto);
      r_rpoca.cod_mod_padre := 7;
      r_rpoca.cod_mad_padre := v_cod_modalidad;
      r_rpoca.concepto      := v_concepto ||' en '||v_cod_moneda;
      r_rpoca.cotizacion    := v_cotizacion;
      r_rpoca.mto_equ_local := abs(v_tot_mon_local);
      r_rpoca.cod_tip_ope_cambio := v_cod_tip_operacion;
      r_rpoca.cod_bco_central    := v_cod_tip_ope_bcp;
      r_rpoca.referencia         := v_referencia;
      g_nro_cuenta               := v_nro_cuenta;
      pal_cie.pr_ins_bol_automaticas(r_rpoca);

      --- genera movimiento x persona, para listados ---
      r_gmovi.cod_usuario   := user;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := 2; -- FIJO para que tome los reportes de cambios
      r_gmovi.cod_modulo    := 7;
      r_gmovi.cod_modalidad := 70;
      r_gmovi.cod_oficina   := v_cod_oficina;
      r_gmovi.nro_cuenta    := null;
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.fec_valor     := v_fec_actual;
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.cod_tra_padre   := 942;
      r_gmovi.cod_transaccion := 760;
      r_gmovi.nro_documento   := v_nro_operacion;
      r_gmovi.nro_documento2  := v_cod_persona;
      r_gmovi.monto           := 0;
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := v_cod_oficina;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      r_gmovi.cod_mod_padre := 7;
      r_gmovi.cod_mad_padre := v_cod_modalidad;
      r_gmovi.concepto      := v_concepto ||' en '||v_cod_moneda;
      r_gmovi.cotizacion    := null;
      r_gmovi.mto_equ_local := null;
      r_gmovi.cod_tip_ope_cambio := null;
      r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      --wa:para pk
      v_hora := to_char(sysdate,'HH24:MI:SS');
      v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');

      if v_cod_modalidad = 72 then  /* ES UNA VENTA */
         --actualiza la posicion
         update lc_posiciones set
                mto_vta_nef_act = nvl(mto_vta_nef_act,0) + v_monto,
                mto_vta_nef_loc = nvl(mto_vta_nef_loc,0) + v_tot_mon_local
         where cod_tip_ope_bcp  = v_cod_tip_ope_bcp
           and cod_moneda       = v_cod_moneda
           and cod_ofi_cambio   = pal_cam.fu_obt_ofi_cambio(v_cod_oficina);
        --inserta posicion si no existe
        if sql%notfound then
           insert into lc_posiciones
               (cod_moneda, cod_tip_ope_bcp, cod_ofi_cambio,
                mto_vta_nef_act, mto_vta_nef_loc)
           values
               (v_cod_moneda, v_cod_tip_ope_bcp,
                pal_cam.fu_obt_ofi_cambio(v_cod_oficina), v_monto,v_tot_mon_local);
        end if;
      else --es una compra
        --actualiza la posicion
        update lc_posiciones set
               mto_com_nef_act = nvl(mto_com_nef_act,0) + abs(v_monto),
               mto_com_nef_loc = nvl(mto_com_nef_loc,0) + abs(v_tot_mon_local)
         where cod_tip_ope_bcp = v_cod_tip_ope_bcp
           and cod_moneda      = v_cod_moneda
           and cod_ofi_cambio  = pal_cam.fu_obt_ofi_cambio(v_cod_oficina);
        --inserta posicion si no existe
        if sql%notfound then
           insert into lc_posiciones
               (cod_moneda, cod_tip_ope_bcp, cod_ofi_cambio,
                mto_com_nef_act, mto_com_nef_loc)
           values
               (v_cod_moneda, v_cod_tip_ope_bcp,
                pal_cam.fu_obt_ofi_cambio(v_cod_oficina), abs(v_monto), abs(v_tot_mon_local));
        end if;
      end if;
  end loop;
  if cur_datos%isopen then
     close cur_datos;
  end if;

END;

/*Proceso que registra movimientos automaticos de compra por operaciones diarias
por Clientes en moneda extranjera. Es llamado desde PR_PRO_COMPRAS - AP 741 - SDC */
PROCEDURE PR_PRO_COM_CLIENTES IS

v_fec_actual        date := pag_cal.fu_obt_fec_actual(7); --fecha de hoy
v_cod_modalidad     NUMBER(04);
v_cod_modulo        NUMBER(04);
v_des_modulo        ba_modulos.descripcion%type;
v_cod_oficina       NUMBER(03);
v_cod_moneda        varchar2(03);
v_monto             NUMBER := 0;
v_hora              varchar2(08);
v_tot_mon_local     NUMBER;
v_cotizacion        ge_cotizaciones.val_conversion%type;
v_cod_tip_operacion lc_tip_operaciones.cod_tip_operacion%type := 17; -- fijo compra cuenta contable
v_cod_tip_ope_bcp   lc_tip_operaciones.cod_tip_ope_bcp%type;
r_gmovi             ge_movimientos%rowtype;
r_rpoca             lc_bol_automaticos_res%rowtype;
v_referencia        lc_bol_automaticos_res.referencia%type;
v_mon_local         ba_monedas.cod_moneda%type :=  pag_gen.fu_obt_mon_local;
v_nro_operacion     ge_movimientos.nro_documento%type;
v_concepto          ge_movimientos.concepto%type;
v_redondeo          number(5);
v_cod_persona       ba_personas.cod_persona%type;
v_nro_cuenta        ge_cuentas.nro_cuenta%type;
v_cod_tra_padre     ge_movimientos.cod_tra_padre%type;
v_usu_hbank         ba_usuarios.cod_usuario%type := fug_obt_pardinamico('COD_USU_HOMEBANKING');
v_ind_inc_hbank     varchar2(1) := fug_obt_pardinamico ('IND_INC_HBANK');


CURSOR CUR_DATOS IS
     --- operaciones de compra y extracciones atm en el extranjero
    select b.cod_moneda, b.cod_modulo, b.cod_oficina, nvl(b.monto,0) monto,
           b.nro_cuenta, nvl(b.cotizacion, a.cotizacion) cotizacion, a.cod_tra_padre,
           '_ATM_EXTERIOR' referencia
    from  ge_movimientos b,ge_movimientos a
    where a.cod_mod_padre in (5,9,16) -- CAJA, TARJETAS, CAJ.SEG
      and a.cod_tra_padre in  ( 374,375,388,986,987,186,486)  -- COMPRA Y EXTRACCIONES EN EL EXTERIOR, COBRO CAJ SEG, DEB. AUT. TARJETAS
      and a.estado = 'N'
      and a.cod_transaccion in (602,978,821)
      and a.monto <> 0
      and b.cod_mod_padre in (5,9,16)
      and b.estado = 'N'
      and b.cod_transaccion = 503
      and b.fecha = a.fecha
      and b.cod_usuario = a.cod_usuario
      and b.hora = a.hora
      and b.nro_documento = a.nro_documento
      and b.cod_moneda <> a.cod_moneda
      and b.monto <> 0
      and b.cod_moneda <> v_mon_local
 union all -- DYDMR-3381
    select b.cod_moneda, b.cod_modulo, b.cod_oficina, nvl(b.monto,0) monto,
           decode(a.cod_transaccion, 196, b.nro_cuenta, a.nro_cuenta) nro_cuenta,
           nvl(b.cotizacion, a.cotizacion) cotizacion, a.cod_tra_padre,
           '_SIPAP'
    from  ge_movimientos b, ge_movimientos a
    where a.cod_mad_padre = 455
      and a.cod_tra_padre in (302,303) -- SNP -- CNFPRSIP-217 - Pago a Proveedores Nueva Transaccion --
      and a.estado = 'N'
      and a.cod_transaccion in (602, 196)
      and a.monto <> 0
      and b.cod_mad_padre = 455
      and b.estado = 'N'
      and b.cod_transaccion in (503, 190)
      and b.fecha = a.fecha
      and b.cod_usuario = a.cod_usuario
      and b.hora = a.hora
      and b.nro_documento = a.nro_documento
      and b.cod_moneda <> a.cod_moneda
      and b.monto <> 0
      and b.cod_moneda <> v_mon_local
      AND ( b.COD_USUARIO = v_usu_hbank
              and v_ind_inc_hbank = 'N' ); -- CANREQVAR-411 - Pago a Proveedores ITGF genera movimientos en linea --
BEGIN
  begin
    select cod_tip_ope_bcp
      into v_cod_tip_ope_bcp
      from lc_tip_operaciones
     where lc_tip_operaciones.cod_tip_operacion = v_cod_tip_operacion;
  exception
    when others then v_cod_tip_ope_bcp := 'A19';
  end;
  ----------------------------------------------------------------
  if cur_datos%isopen then
      close cur_datos;
  end if;
  open cur_datos;
  --v_hora := fug_ini_hora(sysdate,'HH24:MI:SS');
  --wa:para pk
  v_hora := to_char(sysdate,'HH24:MI:SS');
  v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');
  loop
      fetch cur_datos
      into v_cod_moneda,v_cod_modulo,v_cod_oficina,v_monto,v_nro_cuenta, v_cotizacion,
           v_cod_tra_padre,v_referencia;
      exit when cur_datos%notfound;

      Select lower(substr(descripcion,1,9))
        into v_des_modulo
        from ba_modulos
       where cod_modulo = v_cod_modulo;
      /*
      || DYDMR-860 - SC 6884 DIFERENCIA POSICIÓN DE CAMBIOS 26-06-13 - SP 2025
      || como tambien entran las reversiones, esto es en caso de q estas superen a las operaciones
      || No se ajustará el código en esta incidencia
      || Solo la referencia para el detalle de la boleta
      */
      IF v_monto >= 0 THEN
         v_cod_modalidad     := 71;
         v_cod_tip_operacion := 17;
         v_concepto          := 'Compra Div. p/Oper.'||v_des_modulo;
         v_referencia        := 'COM'||v_referencia;
      ELSE
         v_cod_modalidad     := 72;
         v_cod_tip_operacion := 31;
         v_concepto          := 'Venta Div. p/Oper.'||v_des_modulo;
         v_referencia        := 'VTA_REV'||v_referencia;
      END IF;
      -----------------------------------------------------------
      v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, v_cod_modalidad, v_cod_moneda, v_cod_oficina)+1;
      prg_act_par_dinamico('NRO_RECIBO',7, v_cod_modalidad, v_cod_moneda, v_cod_oficina, v_nro_operacion);
      if v_cod_tra_padre in (303, 388,486, 302) then
         v_cotizacion := nvl(v_cotizacion, paw_bce.fu_obt_cotizacion(v_cod_moneda, 'C'));
      else
         v_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda,v_fec_actual);
      end if;
      v_redondeo      := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',7,v_cod_modalidad,v_mon_local);
      v_tot_mon_local := round(nvl(v_cotizacion,0) * v_monto,v_redondeo);

      -- Obtiene el código de Persona
      if v_nro_cuenta is not null then
         v_cod_persona := fug_obt_cli_principal (v_nro_cuenta);
      else
         v_cod_persona := lf_obt_per_entidad;
      end if;

      --- genera movimiento ---
      r_gmovi.cod_usuario   := user;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := 1; -- FIJO 1 para que tome los reportes de cambios
      r_gmovi.cod_modulo    := 7;
      r_gmovi.cod_modalidad := v_cod_modalidad;
      r_gmovi.cod_oficina   := v_cod_oficina;
      r_gmovi.nro_cuenta    := null;
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.fec_valor     := v_fec_actual;
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.cod_tra_padre   := 942;
      r_gmovi.cod_transaccion := 942;
      r_gmovi.nro_documento   := v_nro_operacion;
      r_gmovi.nro_documento2  := null;
      r_gmovi.monto           := abs(v_monto);
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := v_cod_oficina;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      r_gmovi.cod_mod_padre := 7;
      r_gmovi.cod_mad_padre := v_cod_modalidad;
      r_gmovi.concepto      := v_concepto ||' en '||v_cod_moneda;
      r_gmovi.cotizacion    := v_cotizacion;
      r_gmovi.mto_equ_local := abs(v_tot_mon_local);
      r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
      r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
      r_gmovi.cod_persona   := v_cod_persona;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --insertar movimientos en la Tabla de Posición de Cambios
      r_rpoca.cod_usuario   := user;
      r_rpoca.hora          := v_hora;
      r_rpoca.cod_modulo    := 7;
      r_rpoca.cod_modalidad := v_cod_modalidad;
      r_rpoca.cod_oficina   := v_cod_oficina;
      r_rpoca.cod_moneda    := v_cod_moneda;
      r_rpoca.fecha         := v_fec_actual;
      r_rpoca.cod_tra_padre   := 942;
      r_rpoca.cod_transaccion := 942;
      r_rpoca.nro_documento   := v_nro_operacion;
      r_rpoca.monto           := abs(v_monto);
      r_rpoca.cod_mod_padre := 7;
      r_rpoca.cod_mad_padre := v_cod_modalidad;
      r_rpoca.concepto      := v_concepto ||' en '||v_cod_moneda;
      r_rpoca.cotizacion    := v_cotizacion;
      r_rpoca.mto_equ_local := abs(v_tot_mon_local);
      r_rpoca.cod_tip_ope_cambio := v_cod_tip_operacion;
      r_rpoca.cod_bco_central    := v_cod_tip_ope_bcp;
      r_rpoca.referencia    := v_referencia;
      g_nro_cuenta          := v_nro_cuenta;
      pal_cie.pr_ins_bol_automaticas(r_rpoca);

      --- genera movimiento x persona, para listados ---
      r_gmovi.cod_usuario   := user;
      r_gmovi.hora          := v_hora;
      r_gmovi.nro_secuencia := 2; -- FIJO para que tome los reportes de cambios
      r_gmovi.cod_modulo    := 7;
      r_gmovi.cod_modalidad := 70;
      r_gmovi.cod_oficina   := v_cod_oficina;
      r_gmovi.nro_cuenta    := null;
      r_gmovi.cod_moneda    := v_cod_moneda;
      r_gmovi.fec_valor     := v_fec_actual;
      r_gmovi.fecha         := v_fec_actual;
      r_gmovi.cod_tra_padre   := 942;
      r_gmovi.cod_transaccion := 760;
      r_gmovi.nro_documento   := v_nro_operacion;
      r_gmovi.nro_documento2  := v_cod_persona;
      r_gmovi.monto           := 0;
      r_gmovi.estado          := 'N';
      r_gmovi.cod_ofi_origen  := v_cod_oficina;
      r_gmovi.reversado     := 'N';
      r_gmovi.emi_aviso     := 'N';
      r_gmovi.protegido     := 'N';
      r_gmovi.cod_mod_padre := 7;
      r_gmovi.cod_mad_padre := v_cod_modalidad;
      r_gmovi.concepto      := v_concepto ||' en '||v_cod_moneda;
      r_gmovi.cotizacion    := null;
      r_gmovi.mto_equ_local := null;
      r_gmovi.cod_tip_ope_cambio := null;
      r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      --wa:para pk
      v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');
      if v_cod_modalidad = 71 then  /* ES UNA COMPRA */
         --actualiza la posicion
         update lc_posiciones set
                mto_com_nef_act = nvl(mto_com_nef_act,0) + v_monto,
                mto_com_nef_loc = nvl(mto_com_nef_loc,0) + v_tot_mon_local
          where cod_tip_ope_bcp = v_cod_tip_ope_bcp
            and cod_moneda      = v_cod_moneda
            and cod_ofi_cambio  = pal_cam.fu_obt_ofi_cambio(v_cod_oficina);
         --inserta posicion si no existe
         if sql%notfound then
              insert into lc_posiciones
                  (cod_moneda, cod_tip_ope_bcp, cod_ofi_cambio,
                   mto_com_nef_act, mto_com_nef_loc)
              values
                  (v_cod_moneda, v_cod_tip_ope_bcp,
                pal_cam.fu_obt_ofi_cambio(v_cod_oficina), v_monto,v_tot_mon_local);
         end if;
      else --es una venta
        --actualiza la posicion
        update lc_posiciones set
               mto_vta_nef_act = nvl(mto_vta_nef_act,0) + abs(v_monto),
               mto_vta_nef_loc = nvl(mto_vta_nef_loc,0) + abs(v_tot_mon_local)
         where cod_tip_ope_bcp = v_cod_tip_ope_bcp
           and cod_moneda      = v_cod_moneda
           and cod_ofi_cambio  = pal_cam.fu_obt_ofi_cambio(v_cod_oficina);
        --inserta posicion si no existe
        if sql%notfound then
           insert into lc_posiciones
               (cod_moneda, cod_tip_ope_bcp, cod_ofi_cambio,
                mto_com_nef_act, mto_com_nef_loc)
           values
               (v_cod_moneda, v_cod_tip_ope_bcp,
                pal_cam.fu_obt_ofi_cambio(v_cod_oficina), abs(v_monto), abs(v_tot_mon_local));
        end if;
      end if;
  end loop;
  if cur_datos%isopen then
     close cur_datos;
  end if;
 /*fm dydmr 1741 23/04/2015*/
   delete from ba_cod_referencias
   where dominio = 'DAT_OPE_RELACION';

END;

/*Proceso que registra movimientos de compra por el devengamiento de mesa de dinero
en moneda extranjera. Se correrá en el cierre */
PROCEDURE PR_PRO_DEV_MESA IS

v_fec_actual              date := pag_cal.fu_obt_fec_actual(7); --fecha de hoy
v_cod_modalidad           number(04);
v_cod_oficina             number(03);
v_cod_moneda              varchar2(03);
v_tot_interes             number := 0;
v_hora                    varchar2(08);
v_tot_mon_local           number;
v_cotizacion              number;
v_cod_tip_operacion       lc_tip_operaciones.cod_tip_operacion%type := 17; -- fijo compra cuenta contable
v_cod_tip_ope_bcp         lc_tip_operaciones.cod_tip_ope_bcp%type;
r_gmovi                   ge_movimientos%rowtype;
r_rpoca                   lc_bol_automaticos_res%rowtype;
v_mon_local               ba_monedas.cod_moneda%type :=  pag_gen.fu_obt_mon_local;
v_nro_operacion           ge_movimientos.nro_documento%type;
v_tipo                    ge_modalidades.tipo%type;

CURSOR CUR_DATOS IS
   SELECT 'A' tipo, ct.cod_modalidad,ct.cod_oficina cod_ofi_cambio, d.cod_moneda,sum(mto_dev_actual)
     FROM ge_plz_contables pc, md_devengados d, md_cta_documentos ct,
          ge_clientes c, ge_cta_clientes cc
    WHERE d.fecha = v_fec_actual
      AND d.nro_cuenta = ct.nro_cuenta
      AND d.nro_cuenta = cc.nro_cuenta
      AND relacion = 'P'
      AND d.cod_moneda <> v_mon_local
      AND c.cod_persona = cc.cod_persona
      AND EXISTS (SELECT 0 FROM GE_TRANSACCIONES X
                   WHERE X.COD_MODULO = CT.COD_MODULO
                     AND X.COD_MODALIDAD = CT.COD_MODALIDAD
                     AND ((X.COD_TRANSACCION = 901 AND CT.ESTADO <> 'E') OR
                          (X.COD_TRANSACCION = 902 AND CT.ESTADO = 'E'))
                     AND EXISTS (SELECT 0 FROM GE_TIP_ASIENTOS B
                                  WHERE B.COD_TIP_ASIENTO IN ( X.COD_TIP_ASIENTO, X.COD_TIP_ASIENTO2)
                                    AND B.COD_MONEDA = D.COD_MONEDA
                                    AND (B.COD_SIT_CONTABLE IS NULL OR B.COD_SIT_CONTABLE = CT.COD_SIT_CONTABLE)
                                    AND B.COD_RUBRO LIKE '6%')
                  )

      AND pc.can_dias = (select min(can_dias)
                                from ge_plz_contables
                               where can_dias >= (ct.fec_vencimiento-ct.fec_inicio))
     GROUP BY ct.cod_modalidad,ct.cod_oficina,d.cod_moneda
     HAVING sum(mto_dev_actual) <> 0
UNION
   SELECT 'P' tipo, ct.cod_modalidad,ct.cod_oficina cod_ofi_cambio, d.cod_moneda,sum(mto_dev_actual)
     FROM ge_plz_contables pc, md_devengados d, md_cta_documentos ct,
          ge_clientes c, ge_cta_clientes cc
    WHERE d.fecha = v_fec_actual
      AND d.nro_cuenta = ct.nro_cuenta
      AND d.nro_cuenta = cc.nro_cuenta
      AND relacion = 'P'
      AND d.cod_moneda <> v_mon_local
      AND c.cod_persona = cc.cod_persona
      AND EXISTS (SELECT 0 FROM GE_TRANSACCIONES X
                   WHERE X.COD_MODULO = CT.COD_MODULO
                     AND X.COD_MODALIDAD = CT.COD_MODALIDAD
                     AND ((X.COD_TRANSACCION = 901 AND CT.ESTADO <> 'E') OR
                          (X.COD_TRANSACCION = 902 AND CT.ESTADO = 'E'))
                     AND EXISTS (SELECT 0 FROM GE_TIP_ASIENTOS B
                                  WHERE B.COD_TIP_ASIENTO IN ( X.COD_TIP_ASIENTO, X.COD_TIP_ASIENTO2)
                                    AND B.COD_MONEDA = D.COD_MONEDA
                                    AND (B.COD_SIT_CONTABLE IS NULL OR B.COD_SIT_CONTABLE = CT.COD_SIT_CONTABLE)
                                    AND B.COD_RUBRO LIKE '7%')
                  )

      AND pc.can_dias = (select min(can_dias)
                                from ge_plz_contables
                               where can_dias >= (ct.fec_vencimiento-ct.fec_inicio))
     GROUP BY ct.cod_modalidad,ct.cod_oficina,d.cod_moneda
     HAVING sum(mto_dev_actual) <> 0;
BEGIN
  --
  if cur_datos%isopen then
    close cur_datos;
  end if;

   open cur_datos;
   --v_hora := fug_ini_hora(sysdate,'hh24:mi:ss');
    --wa:para pk
   v_hora := to_char(sysdate,'HH24:MI:SS');
   v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');
   loop
    fetch cur_datos into v_tipo, v_cod_modalidad,v_cod_oficina,v_cod_moneda,v_tot_interes;
    exit when cur_datos%notfound;
    if v_tipo = 'A' then--es activo y debe hacer una compra
      v_cod_tip_operacion := 17;
      v_cod_tip_ope_bcp   := 'A19';
      -----------------------------------------------------------
      v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, 71, v_cod_moneda, v_cod_oficina)+1;
      prg_act_par_dinamico('NRO_RECIBO',7, 71, v_cod_moneda, v_cod_oficina, v_nro_operacion);

      v_cotizacion := pag_gen.fu_obt_cotizacion(v_cod_moneda,v_fec_actual);
      v_tot_mon_local := round(nvl(v_cotizacion,0) * v_tot_interes,0);
      --- genera movimiento ---
      r_gmovi.cod_usuario       := user;
      r_gmovi.hora              := v_hora;
      r_gmovi.nro_secuencia     := 1; -- FIJO 1 para que tome los reportes de cambios
      r_gmovi.cod_modulo        := 7;
      r_gmovi.cod_modalidad     := 71;
      r_gmovi.cod_oficina       := v_cod_oficina;
      r_gmovi.nro_cuenta        := null;
      r_gmovi.cod_moneda        := v_cod_moneda;
      r_gmovi.fec_valor         := v_fec_actual;
      r_gmovi.fecha             := v_fec_actual;
      r_gmovi.cod_tra_padre     := 901;
      r_gmovi.cod_transaccion   := 901;
      r_gmovi.nro_documento     := v_nro_operacion;
      r_gmovi.nro_documento2    := null;
      r_gmovi.monto             := v_tot_interes;
      r_gmovi.estado            := 'N';
      r_gmovi.cod_ofi_origen    := v_cod_oficina;
      r_gmovi.reversado         := 'N';
      r_gmovi.emi_aviso         := 'N';
      r_gmovi.protegido         := 'N';
      r_gmovi.cod_mod_padre     := 7;
      r_gmovi.cod_mad_padre     := 71;
      r_gmovi.concepto          := 'Deveng.Interes en '||v_cod_moneda||' 10 '||v_cod_modalidad;
      r_gmovi.cotizacion        := v_cotizacion;
      r_gmovi.mto_equ_local     := v_tot_mon_local;
      r_gmovi.cod_tip_ope_cambio:= v_cod_tip_operacion;
      r_gmovi.COD_BCO_CENTRAL   := v_cod_tip_ope_bcp;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --insertar movimientos en la Tabla de Posición de Cambios
      r_rpoca.cod_usuario       := user;
      r_rpoca.hora              := v_hora;
      r_rpoca.cod_modulo        := 7;
      r_rpoca.cod_modalidad     := 71;
      g_cod_modalidad           := v_cod_modalidad;
      r_rpoca.cod_oficina       := v_cod_oficina;
      r_rpoca.cod_moneda        := v_cod_moneda;
      r_rpoca.fecha             := v_fec_actual;
      r_rpoca.cod_tra_padre     := 901;
      r_rpoca.cod_transaccion   := 901;
      r_rpoca.nro_documento     := v_nro_operacion;
      r_rpoca.monto             := v_tot_interes;
      r_rpoca.cod_mod_padre     := 7;
      r_rpoca.cod_mad_padre     := 71;
      r_rpoca.concepto          := 'Deveng.Interes en '||v_cod_moneda||' 10 '||v_cod_modalidad;
      r_rpoca.cotizacion        := v_cotizacion;
      r_rpoca.mto_equ_local     := v_tot_mon_local;
      r_rpoca.cod_tip_ope_cambio:= v_cod_tip_operacion;
      r_rpoca.COD_BCO_CENTRAL   := v_cod_tip_ope_bcp;
      r_rpoca.referencia        := 'COM_DEV_ACT_MESA';
      pal_cie.pr_ins_bol_automaticas(r_rpoca);

      --- genera movimiento x persona, para listados ---
      r_gmovi.cod_usuario       := user;
      r_gmovi.hora              := v_hora;
      r_gmovi.nro_secuencia     := 2; -- FIJO para que tome los reportes de cambios
      r_gmovi.cod_modulo        := 7;
      r_gmovi.cod_modalidad     := 70;
      r_gmovi.cod_oficina       := v_cod_oficina;
      r_gmovi.nro_cuenta        := null;
      r_gmovi.cod_moneda        := v_cod_moneda;
      r_gmovi.fec_valor         := v_fec_actual;
      r_gmovi.fecha             := v_fec_actual;
      r_gmovi.cod_tra_padre     := 901;
      r_gmovi.cod_transaccion   := 760;
      r_gmovi.nro_documento     := v_nro_operacion;
      r_gmovi.nro_documento2    := LF_OBT_PER_ENTIDAD;
      r_gmovi.monto             := 0;
      r_gmovi.estado            := 'N';
      r_gmovi.cod_ofi_origen    := v_cod_oficina;
      r_gmovi.reversado         := 'N';
      r_gmovi.emi_aviso         := 'N';
      r_gmovi.protegido         := 'N';
      r_gmovi.cod_mod_padre     := 7;
      r_gmovi.cod_mad_padre     := 71;
      r_gmovi.concepto          := 'Deveng.Interes en '||v_cod_moneda||' 10 '||v_cod_modalidad;
      r_gmovi.cotizacion        := null;
      r_gmovi.mto_equ_local     := null;
      r_gmovi.cod_tip_ope_cambio:= null;
      r_gmovi.COD_BCO_CENTRAL   := v_cod_tip_ope_bcp;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      --wa:para pk
      v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');
      --actualizar posición
      update lc_posiciones set
        mto_com_nef_act = nvl(mto_com_nef_act,0) + v_tot_interes,
        mto_com_nef_loc = nvl(mto_com_nef_loc,0) + v_tot_mon_local
      where cod_tip_ope_bcp = v_cod_tip_ope_bcp
        and cod_moneda = v_cod_moneda
        and cod_ofi_cambio = pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina);
      --insertar posición si no existe
      if sql%notfound then
        insert into lc_posiciones
        (cod_moneda,cod_tip_ope_bcp,cod_ofi_cambio,
        mto_com_nef_act,mto_com_nef_loc)
        values
        (v_cod_moneda, v_cod_tip_ope_bcp,pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina),
        v_tot_interes,v_tot_mon_local);
      end if;
    else
      v_cod_tip_operacion := 31;
      v_cod_tip_ope_bcp := 'B27';
      v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, 72, v_cod_moneda, v_cod_oficina)+1;
      prg_act_par_dinamico('NRO_RECIBO',7, 72, v_cod_moneda, v_cod_oficina, v_nro_operacion);

      v_cotizacion := pag_gen.FU_OBT_COTIZACION(v_cod_moneda,v_fec_actual);
      v_tot_mon_local := ROUND(NVL(v_cotizacion,0) * v_tot_interes,0);
      --- genera movimiento ---
      r_gmovi.cod_usuario        := user;
      r_gmovi.hora               := v_hora;
      r_gmovi.nro_secuencia      := 1; -- FIJO 1 para que tome los reportes de cambios
      r_gmovi.cod_modulo         := 7;
      r_gmovi.cod_modalidad      := 72;
      r_gmovi.cod_oficina        := v_cod_oficina;
      r_gmovi.nro_cuenta         := null;
      r_gmovi.cod_moneda         := v_cod_moneda;
      r_gmovi.fec_valor          := v_fec_actual;
      r_gmovi.fecha              := v_fec_actual;
      r_gmovi.cod_tra_padre      := 901;
      r_gmovi.cod_transaccion    := 901;
      r_gmovi.nro_documento      := v_nro_operacion;
      r_gmovi.nro_documento2     := null;
      r_gmovi.monto              := v_tot_interes;
      r_gmovi.estado             := 'N';
      r_gmovi.cod_ofi_origen     := v_cod_oficina;
      r_gmovi.reversado          := 'N';
      r_gmovi.emi_aviso          := 'N';
      r_gmovi.protegido          := 'N';
      r_gmovi.cod_mod_padre      := 7;
      r_gmovi.cod_mad_padre      := 72;
      r_gmovi.concepto           := 'Deveng.Interes en '||v_cod_moneda||' 10 '||v_cod_modalidad;
      r_gmovi.cotizacion         := v_cotizacion;
      r_gmovi.mto_equ_local      := v_tot_mon_local;
      r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
      r_gmovi.COD_BCO_CENTRAL    := v_cod_tip_ope_bcp;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --insertar movimientos en la Tabla de Posición de Cambios
      r_rpoca.cod_usuario        := user;
      r_rpoca.hora               := v_hora;
      r_rpoca.cod_modulo         := 7;
      r_rpoca.cod_modalidad      := 72;
      g_cod_modalidad            := v_cod_modalidad;
      r_rpoca.cod_oficina        := v_cod_oficina;
      r_rpoca.cod_moneda         := v_cod_moneda;
      r_rpoca.fecha              := v_fec_actual;
      r_rpoca.cod_tra_padre      := 901;
      r_rpoca.cod_transaccion    := 901;
      r_rpoca.nro_documento      := v_nro_operacion;
      r_rpoca.monto              := v_tot_interes;
      r_rpoca.cod_mod_padre      := 7;
      r_rpoca.cod_mad_padre      := 72;
      r_rpoca.concepto           := 'Deveng.Interes en '||v_cod_moneda||' 10 '||v_cod_modalidad;
      r_rpoca.cotizacion         := v_cotizacion;
      r_rpoca.mto_equ_local      := v_tot_mon_local;
      r_rpoca.cod_tip_ope_cambio := v_cod_tip_operacion;
      r_rpoca.COD_BCO_CENTRAL    := v_cod_tip_ope_bcp;
      r_rpoca.referencia        := 'VTA_DEV_PAS_MESA';
      pal_cie.pr_ins_bol_automaticas(r_rpoca);

      --- genera movimiento x persona, para listados ---
      r_gmovi.cod_usuario        := user;
      r_gmovi.hora               := v_hora;
      r_gmovi.nro_secuencia      := 2; -- FIJO para que tome los reportes de cambios
      r_gmovi.cod_modulo         := 7;
      r_gmovi.cod_modalidad      := 70;
      r_gmovi.cod_oficina        := v_cod_oficina;
      r_gmovi.nro_cuenta         := null;
      r_gmovi.cod_moneda         := v_cod_moneda;
      r_gmovi.fec_valor          := v_fec_actual;
      r_gmovi.fecha              := v_fec_actual;
      r_gmovi.cod_tra_padre      := 901;
      r_gmovi.cod_transaccion    := 760;
      r_gmovi.nro_documento      := v_nro_operacion;
      r_gmovi.nro_documento2     := LF_OBT_PER_ENTIDAD;
      r_gmovi.monto              := 0;
      r_gmovi.estado             := 'N';
      r_gmovi.cod_ofi_origen     := v_cod_oficina;
      r_gmovi.reversado          := 'N';
      r_gmovi.emi_aviso          := 'N';
      r_gmovi.protegido          := 'N';
      r_gmovi.cod_mod_padre      := 7;
      r_gmovi.cod_mad_padre      := 72;
      r_gmovi.concepto           := 'Deveng.Interes en '||v_cod_moneda||' 10 '||v_cod_modalidad;
      r_gmovi.cotizacion         := null;
      r_gmovi.mto_equ_local      := null;
      r_gmovi.cod_tip_ope_cambio := null;
      r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
      pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

      --v_hora := pag_gen.fu_obt_sig_segundo(v_hora);
      --wa:para pk
      v_hora:= fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');
      --actualizar posición
      update lc_posiciones set
      mto_vta_nef_act = nvl(mto_vta_nef_act,0) + v_tot_interes,
      mto_vta_nef_loc = nvl(mto_vta_nef_loc,0) + v_tot_mon_local
      where cod_tip_ope_bcp = v_cod_tip_ope_bcp
      and cod_moneda = v_cod_moneda
      and cod_ofi_cambio = pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina);
      --insertar posición si no existe
      if sql%notfound then
        insert into lc_posiciones
        (cod_moneda,cod_tip_ope_bcp,cod_ofi_cambio,
        mto_vta_nef_act,mto_vta_nef_loc)
        values
        (v_cod_moneda, v_cod_tip_ope_bcp,pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina),
        v_tot_interes,v_tot_mon_local);
      end if;
    end if;
   end loop;

  if cur_datos%isopen then
    close cur_datos;
  end if;

end;
/* Inserta datos en la Tabla LC_RES_POS_CAMBIOS */
PROCEDURE PR_INS_BOL_AUTOMATICAS
   (RP_RPOCA IN lc_bol_automaticos_res%ROWTYPE
   ) IS
   ---
   v_mon_local           ba_monedas.cod_moneda%type :=  pag_gen.fu_obt_mon_local;
   ---
   cursor c_dev_ahorros (p_fecha date,
                         p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                         p_cod_modalidad ge_cuentas.cod_modalidad%type,
                         p_cod_oficina ge_cuentas.cod_oficina%type) is
   SELECT (MTO_INTERES), GE_CUENTAS.nro_cuenta
     FROM GE_CUENTAS, AH_DEVENGADOS
    WHERE FECHA = p_fecha
      AND AH_DEVENGADOS.COD_MONEDA <> v_mon_local
      AND GE_CUENTAS.NRO_CUENTA = AH_DEVENGADOS.NRO_CUENTA
      and COD_MODALIDAD = p_cod_modalidad
      and cod_oficina = p_cod_oficina
      and AH_DEVENGADOS.COD_MONEDA = p_cod_moneda
      and MTO_INTERES <> 0;
   --- PR_PRO_DEV_AHORROS
   cursor c_dev_prestamos (p_fecha date,
                           p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                           p_cod_modalidad ge_cuentas.cod_modalidad%type,
                           p_cod_oficina ge_cuentas.cod_oficina%type) is
   SELECT (MTO_DEV_ACTUAL), CT.nro_cuenta
     FROM GE_PLZ_CONTABLES PC, PR_DEVENGADOS D, PR_CTA_PRESTAMOS CT,
          GE_CLIENTES C, GE_CTA_CLIENTES CC, GE_MODALIDADES MO
    WHERE D.FECHA = p_fecha
      AND D.NRO_CUENTA = CT.NRO_CUENTA
      AND D.NRO_CUENTA = CC.NRO_CUENTA
      AND RELACION = 'P'
      --AND (CT.ESTADO = 'C' AND D.CATEGORIA < 3)-- AP 2809 Solo considerar devengados de prestamos vigentes, estos afectan a rubros de perdida/ganancia
      /*dydmr 1796 28/04/2015 FM */
      AND ((CT.ESTADO = 'C' AND D.CATEGORIA < 3) or (CT.ESTADO = 'N' and ct.fec_cancelacion = d.fecha))
      AND d.COD_MONEDA <> v_mon_local
      AND C.COD_PERSONA = CC.COD_PERSONA
      AND MO.COD_MODULO = CT.COD_MODULO
      AND MO.COD_MODALIDAD = CT.COD_MODALIDAD
      AND EXISTS (SELECT 0
                    FROM GE_TIP_ASIENTOS S, GE_TRANSACCIONES T
                   WHERE T.COD_MODULO = CT.COD_MODULO
                     AND T.COD_MODALIDAD = CT.COD_MODALIDAD
                     AND T.COD_TRANSACCION = 901
                     AND T.COD_TIP_ASIENTO = S.COD_TIP_ASIENTO
                     AND S.COD_MONEDA       = CT.COD_MONEDA
                     AND SUBSTR(S.COD_RUBRO,14,2) not in ('99','98')
                     AND (S.COD_SEC_CONTABLE = C.COD_SEC_CONTABLE or cod_sec_contable is null)
                     AND (S.IND_RESIDENTE    = C.RESIDENTE      OR IND_RESIDENTE = 'X')
                     AND (S.est_cuenta       = d.estado         or nvl(S.est_cuenta,'X') = 'X')
                     AND (S.tip_cuenta       = ct.tipo     or nvl(S.tip_cuenta,'X') = 'X')
                     AND (S.tip_interes      = ct.tip_interes    or nvl(S.tip_interes,'X') = 'X')
                     AND (S.tip_renovacion   = nvl(ct.tip_renovacion,'A') or nvl(S.tip_renovacion,'X') = 'X')
                     AND (S.cat_automatica   = d.categoria or nvl(S.cat_automatica,-1) = -1)
                         )
      AND PC.CAN_DIAS = (select min(CAN_DIAS)
                           from GE_PLZ_CONTABLES
                          where CAN_DIAS >= (CT.FEC_VENCIMIENTO-CT.FEC_INICIO))
      and ct.COD_MODALIDAD = p_cod_modalidad
      and ct.cod_oficina = p_cod_oficina
      and d.COD_MONEDA = p_cod_moneda
      and MTO_DEV_ACTUAL <> 0;
   --- PR_PRO_DEV_PRESTAMOS
   cursor c_vta_ope_GEN_otros (p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                    p_cod_modulo ge_cuentas.cod_modulo%type,
                    p_cod_oficina ge_cuentas.cod_oficina%type) is
   SELECT (NVL(MONTO,0)) monto, a.fecha, a.hora, a.cod_usuario, a.nro_secuencia
     FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
    WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       and a.cod_modulo NOT IN (4,6)
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'D'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
       and a.COD_MODULO = p_cod_modulo
       and a.cod_oficina = p_cod_oficina
       and a.COD_MONEDA = p_cod_moneda
       and NVL(MONTO,0) <> 0;

   cursor c_VTA_OPE_CTE_PREVISION (p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                    p_cod_modulo ge_cuentas.cod_modulo%type,
                    p_cod_oficina ge_cuentas.cod_oficina%type) is
   SELECT (NVL(MONTO,0)) monto, a.fecha, a.hora, a.cod_usuario, a.nro_secuencia
     FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
    WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       and a.cod_modulo = 4
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Excluye Grupo de TransaccioNES DE Compra de Previsiones--
       and exists (select 1 from ge_gru_transacciones_det x
                    where x.cod_gru_transaccion = 301
                      and x.cod_transaccion = a.cod_transaccion
                      and x.cod_modulo = a.cod_modulo
                      and x.cod_modalidad = a.cod_modalidad)
       -----------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'D'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
       and a.COD_MODULO = p_cod_modulo
       and a.cod_oficina = p_cod_oficina
       and a.COD_MONEDA = p_cod_moneda
       and NVL(MONTO,0) <> 0;

   cursor c_vta_ope_CTE_OTROS (p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                    p_cod_modulo ge_cuentas.cod_modulo%type,
                    p_cod_oficina ge_cuentas.cod_oficina%type) is
   SELECT (NVL(MONTO,0)) monto, a.fecha, a.hora, a.cod_usuario, a.nro_secuencia
     FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
    WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       and a.cod_modulo = 4
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Excluye Grupo de TransaccioNES DE Compra de Previsiones--
       and not exists (select 1 from ge_gru_transacciones_det x
                        where x.cod_gru_transaccion = 301
                          and x.cod_transaccion = a.cod_transaccion
                          and x.cod_modulo = a.cod_modulo
                          and x.cod_modalidad = a.cod_modalidad)
       -----------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'D'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
       and a.COD_MODULO = p_cod_modulo
       and a.cod_oficina = p_cod_oficina
       and a.COD_MONEDA = p_cod_moneda
       and NVL(MONTO,0) <> 0;
   
   cursor c_VTA_OPE_PRE_PREVISION (p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                    p_cod_modulo ge_cuentas.cod_modulo%type,
                    p_cod_oficina ge_cuentas.cod_oficina%type) is
   SELECT (NVL(MONTO,0)) monto, a.fecha, a.hora, a.cod_usuario, a.nro_secuencia
     FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
    WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       and a.cod_modulo = 6
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Excluye Grupo de TransaccioNES DE Compra de Previsiones--
       and exists (select 1 from ge_gru_transacciones_det x
                    where x.cod_gru_transaccion = 301
                      and x.cod_transaccion = a.cod_transaccion
                      and x.cod_modulo = a.cod_modulo
                      and x.cod_modalidad = a.cod_modalidad)
       -----------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'D'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
       and a.COD_MODULO = p_cod_modulo
       and a.cod_oficina = p_cod_oficina
       and a.COD_MONEDA = p_cod_moneda
       and NVL(MONTO,0) <> 0;
       
   cursor c_vta_ope_PRE_OTROS (p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                    p_cod_modulo ge_cuentas.cod_modulo%type,
                    p_cod_oficina ge_cuentas.cod_oficina%type) is
   SELECT (NVL(MONTO,0)) monto, a.fecha, a.hora, a.cod_usuario, a.nro_secuencia
     FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
    WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       and a.cod_modulo = 6
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Excluye Grupo de TransaccioNES DE Compra de Previsiones--
       and not exists (select 1 from ge_gru_transacciones_det x
                        where x.cod_gru_transaccion = 301
                          and x.cod_transaccion = a.cod_transaccion
                          and x.cod_modulo = a.cod_modulo
                          and x.cod_modalidad = a.cod_modalidad)
       -----------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'D'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
       and a.COD_MODULO = p_cod_modulo
       and a.cod_oficina = p_cod_oficina
       and a.COD_MONEDA = p_cod_moneda
       and NVL(MONTO,0) <> 0;
       
   --- PR_PRO_VENTAS
   cursor c_vta_apuntes (p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                         p_cod_modulo ge_cuentas.cod_modulo%type,
                         p_cod_oficina ge_cuentas.cod_oficina%type) is
   SELECT (NVL(MONTO,0)) monto, a.fecha, a.hora, a.cod_usuario, a.nro_secuencia
     FROM CB_RUBROS X, GE_MOVIMIENTOS a
    WHERE a.COD_MOD_PADRE <> 7
      AND A.COD_MONEDA <> v_mon_local
      AND ESTADO = 'N'
      AND A.TIP_MOV_RUBRO= 'D'
      AND X.COD_RUBRO(+) = A.COD_RUBRO
      AND ((SUBSTR(A.COD_RUBRO,-2,2) IN ('98','99')) OR
          (X.COD_MONEDA = v_mon_local) or
           (SUBSTR(A.COD_RUBRO,1,1) IN ('6','7')))
      and a.COD_MODULO = p_cod_modulo
      and a.cod_oficina = p_cod_oficina
      and a.COD_MONEDA = p_cod_moneda
      and NVL(MONTO,0) <> 0;
   ---
   cursor c_vta_internas (p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                          p_cod_modulo ge_cuentas.cod_modulo%type,
                          p_cod_oficina ge_cuentas.cod_oficina%type) is
   SELECT (NVL(MONTO,0)) monto, a.fecha, a.hora, a.cod_usuario, a.nro_secuencia
     FROM CB_RUBROS X, ge_movimientos a
    WHERE a.COD_MOD_PADRE IN(1, 2)
      AND A.COD_TRA_PADRE=100
      AND A.COD_MONEDA <> v_mon_local
      AND ESTADO = 'N'
      AND A.TIP_MOV_RUBRO= 'C' --- Ajuste realizado por ICL 13/01/2012 en base a Incidencia reportada por Victor P. ya que la parte del crédito debe ser la moneda local
      AND A.Cod_Rubro is not null
      AND SUBSTR(a.COD_RUBRO,1,1) IN ('1','2')
      AND X.COD_RUBRO = A.COD_RUBRO
      and exists(select c.* from ge_movimientos c
                  where c.hora=a.hora
                    and c.fecha=a.fecha
                    and c.cod_usuario=a.cod_usuario
                    and c.cod_rubro is not null
                    and c.cod_rubro <> a.cod_rubro
                    AND  (
                         (SUBSTR(c.COD_RUBRO,14,2) IN ('98','99')
                      AND SUBSTR(c.COD_RUBRO,1,1) IN ('6','7'))
                      OR (
                          SUBSTR(c.COD_RUBRO,14,2) IN ('98','99')
                      AND SUBSTR(c.COD_RUBRO,1,1) IN ('1','2')
                          )
                        )
                   )
      and a.COD_MODULO = p_cod_modulo
      and a.cod_oficina = p_cod_oficina
      and a.COD_MONEDA = p_cod_moneda
      and NVL(MONTO,0) <> 0;
  
 --SDRES4COVI-81 - Resolución 4 - Previsiones Constitución y Diferimiento Productos RES04 
   cursor c_vta_pre_res4 (p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                          p_cod_modulo ge_cuentas.cod_modulo%type,
                          p_cod_oficina ge_cuentas.cod_oficina%type) is
  
    SELECT (NVL(MONTO,0)) monto, a.nro_cuenta, a.fecha, a.hora, a.cod_usuario, a.nro_secuencia
      FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       and a.cod_modulo = 6
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Incluye Grupo de Transacciones de Compra de Previsiones Resolución 4--
       and exists (select 1 from ge_gru_transacciones_det x
                        where x.cod_gru_transaccion = 400
                          and x.cod_transaccion = a.cod_transaccion
                          and x.cod_modulo = a.cod_modulo
                          and x.cod_modalidad = a.cod_modalidad)
       -----------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'D'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) = '1'))
                   )
      and a.COD_MODULO = p_cod_modulo
      and a.cod_oficina = p_cod_oficina
      and a.COD_MONEDA = p_cod_moneda
      and NVL(MONTO,0) <> 0; 
      
      
      
   --- PR_PRO_COMPRAS
   cursor c_COM_OPE_PRE_OTROS (p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                     p_cod_modulo ge_cuentas.cod_modulo%type,
                     p_cod_oficina ge_cuentas.cod_oficina%type) is
   SELECT (NVL(MONTO,0)) monto, a.fecha, a.hora, a.cod_usuario, a.nro_secuencia
     FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
    WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND A.COD_MODULO = 6 /*DYDMR2255*/
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Excluye Grupo de TransaccioNES DE Compra de Previsiones--
       and not exists (select 1 from ge_gru_transacciones_det x
                        where x.cod_gru_transaccion = 300
                          and x.cod_transaccion = a.cod_transaccion
                          and x.cod_modulo = a.cod_modulo
                          and x.cod_modalidad = a.cod_modalidad)
       --------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'C'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND (A.EST_CUENTA = C.EST_CUENTA OR C.EST_CUENTA IS NULL) /*DYDMR2255*/
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
      and a.COD_MODULO = p_cod_modulo
      and cod_oficina = p_cod_oficina
      and COD_MONEDA = p_cod_moneda
      and NVL(MONTO,0) <> 0;

   cursor c_COM_OPE_PRE_PREVISION (p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                     p_cod_modulo ge_cuentas.cod_modulo%type,
                     p_cod_oficina ge_cuentas.cod_oficina%type) is
   SELECT (NVL(MONTO,0)) monto, a.fecha, a.hora, a.cod_usuario, a.nro_secuencia
     FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
    WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND A.COD_MODULO = 6 /*DYDMR2255*/
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Incluye Grupo de TransaccioNES DE Compra de Previsiones--
       and exists (select 1 from ge_gru_transacciones_det x
                     where x.cod_gru_transaccion = 300
                       and x.cod_transaccion = a.cod_transaccion
                       and x.cod_modulo = a.cod_modulo
                       and x.cod_modalidad = a.cod_modalidad)
       --------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'C'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND (A.EST_CUENTA = C.EST_CUENTA OR C.EST_CUENTA IS NULL) /*DYDMR2255*/
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
      and a.COD_MODULO = p_cod_modulo
      and cod_oficina = p_cod_oficina
      and COD_MONEDA = p_cod_moneda
      and NVL(MONTO,0) <> 0;

   cursor c_COM_OPE_GEN_OTROS (p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                     p_cod_modulo ge_cuentas.cod_modulo%type,
                     p_cod_oficina ge_cuentas.cod_oficina%type) is
   SELECT (NVL(MONTO,0)) monto, a.fecha, a.hora, a.cod_usuario, a.nro_secuencia
     FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
    WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND A.COD_MODULO NOT IN (4,6) /*DYDMR2255*/
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'C'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
      and a.COD_MODULO = p_cod_modulo
      and cod_oficina = p_cod_oficina
      and COD_MONEDA = p_cod_moneda
      and NVL(MONTO,0) <> 0;

   cursor c_COM_OPE_CTE_PREVISION (p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                     p_cod_modulo ge_cuentas.cod_modulo%type,
                     p_cod_oficina ge_cuentas.cod_oficina%type) is
   SELECT (NVL(MONTO,0)) monto, a.fecha, a.hora, a.cod_usuario, a.nro_secuencia
     FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
    WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND A.COD_MODULO = 4 /*DYDMR2255*/
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Excluye Grupo de TransaccioNES DE Compra de Previsiones--
       and exists (select 1 from ge_gru_transacciones_det x
                    where x.cod_gru_transaccion = 300
                      and x.cod_transaccion = a.cod_transaccion
                      and x.cod_modulo = a.cod_modulo
                      and x.cod_modalidad = a.cod_modalidad)
       --------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'C'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
      and a.COD_MODULO = p_cod_modulo
      and cod_oficina = p_cod_oficina
      and COD_MONEDA = p_cod_moneda
      and NVL(MONTO,0) <> 0;

   cursor c_COM_OPE_CTE_OTROS (p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                     p_cod_modulo ge_cuentas.cod_modulo%type,
                     p_cod_oficina ge_cuentas.cod_oficina%type) is
   SELECT (NVL(MONTO,0)) monto, a.fecha, a.hora, a.cod_usuario, a.nro_secuencia
     FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
    WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND A.COD_MODULO = 4 /*DYDMR2255*/
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       --AND COD_OFI_ORIGEN = COD_OFICINA
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Excluye Grupo de TransaccioNES DE Compra de Previsiones--
       and not exists (select 1 from ge_gru_transacciones_det x
                        where x.cod_gru_transaccion = 300
                          and x.cod_transaccion = a.cod_transaccion
                          and x.cod_modulo = a.cod_modulo
                          and x.cod_modalidad = a.cod_modalidad)
       --------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'C'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) IN ('6','7')))
                   )
      and a.COD_MODULO = p_cod_modulo
      and cod_oficina = p_cod_oficina
      and COD_MONEDA = p_cod_moneda
      and NVL(MONTO,0) <> 0;
   ---
   cursor c_pre_genericas (p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                           p_cod_modulo ge_cuentas.cod_modulo%type,
                           p_cod_oficina ge_cuentas.cod_oficina%type) is
   SELECT (NVL(MONTO,0)) monto, a.fecha, a.hora, a.cod_usuario, a.nro_secuencia
     FROM CB_RUBROS X, GE_MOVIMIENTOS a
    WHERE a.COD_MOD_PADRE <> 7
      AND A.COD_MONEDA <> v_mon_local
      AND ESTADO = 'N'
      AND A.TIP_MOV_RUBRO= 'C'
      AND X.COD_RUBRO(+) = A.COD_RUBRO
      AND ((SUBSTR(A.COD_RUBRO,-2,2) IN ('98','99')) OR
          (X.COD_MONEDA = v_mon_local) or
           (SUBSTR(A.COD_RUBRO,1,1) IN ('6','7')))
      and a.COD_MODULO = p_cod_modulo
      and a.cod_oficina = p_cod_oficina
      and a.COD_MONEDA = p_cod_moneda
      and NVL(MONTO,0) <> 0;
   ---
   cursor c_com_apuntes (p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                         p_cod_modulo ge_cuentas.cod_modulo%type,
                         p_cod_oficina ge_cuentas.cod_oficina%type) is
   SELECT (NVL(MONTO,0)) monto, a.fecha, a.hora, a.cod_usuario, a.nro_secuencia
     FROM CB_RUBROS X, ge_movimientos a
    WHERE a.COD_MOD_PADRE IN(1, 2)
      AND A.COD_TRA_PADRE=100
      AND A.COD_MONEDA <> v_mon_local
      AND ESTADO = 'N'
      AND A.TIP_MOV_RUBRO= 'D' --- Ajuste realizado por ICL 13/01/2012 en base a Incidencia reportada por Victor P. ya que la parte del débito debe ser la moneda local
      AND A.Cod_Rubro is not null
      AND X.COD_RUBRO = A.COD_RUBRO
      AND SUBSTR(a.COD_RUBRO,1,1) IN ('1','2')
      and exists(select c.* from ge_movimientos c
                  where c.hora=a.hora
                    and c.fecha=a.fecha
                    and c.cod_usuario=a.cod_usuario
                    and c.cod_rubro is not null
                    and c.cod_rubro <> a.cod_rubro
                    AND (
                            (SUBSTR(c.COD_RUBRO,14,2) IN ('98','99')
                         AND SUBSTR(c.COD_RUBRO,1,1) IN ('6','7'))
                      OR (
                             SUBSTR(c.COD_RUBRO,14,2) IN ('98','99')
                         AND SUBSTR(c.COD_RUBRO,1,1) IN ('1','2')
                          )
                        )
                   )
      and a.COD_MODULO = p_cod_modulo
      and a.cod_oficina = p_cod_oficina
      and a.COD_MONEDA = p_cod_moneda
      and NVL(MONTO,0) <> 0;
   ---
   cursor c_dev_mesa_act (p_fecha date,
                          p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                          p_cod_modalidad ge_cuentas.cod_modalidad%type,
                          p_cod_oficina ge_cuentas.cod_oficina%type) is
   SELECT (mto_dev_actual), ct.nro_cuenta
     FROM ge_plz_contables pc, md_devengados d, md_cta_documentos ct,
          ge_clientes c, ge_cta_clientes cc
    WHERE d.fecha = p_fecha
      AND d.nro_cuenta = ct.nro_cuenta
      AND d.nro_cuenta = cc.nro_cuenta
      AND relacion = 'P'
      AND d.cod_moneda <> v_mon_local
      AND c.cod_persona = cc.cod_persona
      AND EXISTS (SELECT 0 FROM GE_TRANSACCIONES X
                   WHERE X.COD_MODULO = CT.COD_MODULO
                     AND X.COD_MODALIDAD = CT.COD_MODALIDAD
                     AND ((X.COD_TRANSACCION = 901 AND CT.ESTADO <> 'E') OR
                          (X.COD_TRANSACCION = 902 AND CT.ESTADO = 'E'))
                     AND EXISTS (SELECT 0 FROM GE_TIP_ASIENTOS B
                                  WHERE B.COD_TIP_ASIENTO IN ( X.COD_TIP_ASIENTO, X.COD_TIP_ASIENTO2)
                                    AND B.COD_MONEDA = D.COD_MONEDA
                                    AND (B.COD_SIT_CONTABLE IS NULL OR B.COD_SIT_CONTABLE = CT.COD_SIT_CONTABLE)
                                    AND B.COD_RUBRO LIKE '6%')
                  )

      AND pc.can_dias = (select min(can_dias)
                                from ge_plz_contables
                               where can_dias >= (ct.fec_vencimiento-ct.fec_inicio))
      and ct.COD_MODALIDAD = p_cod_modalidad
      and ct.cod_oficina = p_cod_oficina
      and d.COD_MONEDA = p_cod_moneda
      and mto_dev_actual <> 0;
   ---
   cursor c_dev_mesa_pas (p_fecha date,
                          p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                          p_cod_modalidad ge_cuentas.cod_modalidad%type,
                          p_cod_oficina ge_cuentas.cod_oficina%type) is
   SELECT (mto_dev_actual), ct.nro_cuenta
     FROM ge_plz_contables pc, md_devengados d, md_cta_documentos ct,
          ge_clientes c, ge_cta_clientes cc
    WHERE d.fecha = p_fecha
      AND d.nro_cuenta = ct.nro_cuenta
      AND d.nro_cuenta = cc.nro_cuenta
      AND relacion = 'P'
      AND d.cod_moneda <> v_mon_local
      AND c.cod_persona = cc.cod_persona
      AND EXISTS (SELECT 0 FROM GE_TRANSACCIONES X
                   WHERE X.COD_MODULO = CT.COD_MODULO
                     AND X.COD_MODALIDAD = CT.COD_MODALIDAD
                     AND ((X.COD_TRANSACCION = 901 AND CT.ESTADO <> 'E') OR
                          (X.COD_TRANSACCION = 902 AND CT.ESTADO = 'E'))
                     AND EXISTS (SELECT 0 FROM GE_TIP_ASIENTOS B
                                  WHERE B.COD_TIP_ASIENTO IN ( X.COD_TIP_ASIENTO, X.COD_TIP_ASIENTO2)
                                    AND B.COD_MONEDA = D.COD_MONEDA
                                    AND (B.COD_SIT_CONTABLE IS NULL OR B.COD_SIT_CONTABLE = CT.COD_SIT_CONTABLE)
                                    AND B.COD_RUBRO LIKE '7%')
                  )

      AND pc.can_dias = (select min(can_dias)
                                from ge_plz_contables
                               where can_dias >= (ct.fec_vencimiento-ct.fec_inicio))
      and ct.COD_MODALIDAD = p_cod_modalidad
      and ct.cod_oficina = p_cod_oficina
      and d.COD_MONEDA = p_cod_moneda
      and mto_dev_actual <> 0;
 
 --SDRES4COVI-81 - Resolución 4 - Previsiones Constitución y Diferimiento Productos RES04      
 cursor c_comp_prev_resol4(p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                           p_cod_modulo ge_cuentas.cod_modulo%type,
                           p_cod_oficina ge_cuentas.cod_oficina%type) is
    SELECT (NVL(MONTO,0)) monto, a.nro_cuenta, a.fecha, a.hora, a.cod_usuario, a.nro_secuencia
      FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE <> 7
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND A.COD_MODULO = 6
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --Incluye Grupo de Transacciones de Compra de Previsiones Resolución 4--
       and exists (select 1 from ge_gru_transacciones_det x
                        where x.cod_gru_transaccion = 400
                          and x.cod_transaccion = a.cod_transaccion
                          and x.cod_modulo = a.cod_modulo
                          and x.cod_modalidad = a.cod_modalidad)
       --------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'C'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,1) = '1'))
                   )
      and a.COD_MODULO = p_cod_modulo
      and cod_oficina = p_cod_oficina
      and COD_MONEDA = p_cod_moneda
      and NVL(MONTO,0) <> 0;      
      
 --SDL6380INR-1 - Impuesto a la renta a no residentes - INR
 cursor c_comp_mov_ret_inr(p_cod_moneda AH_DEVENGADOS.COD_MONEDA%type,
                           p_cod_modulo ge_cuentas.cod_modulo%type,
                           p_cod_oficina ge_cuentas.cod_oficina%type) is
    SELECT (NVL(MONTO,0)) monto, a.nro_cuenta, a.fecha, a.hora, a.cod_usuario, a.nro_secuencia
      FROM GE_TRANSACCIONES b, GE_MOVIMIENTOS a
     WHERE a.COD_MOD_PADRE = 3
       AND COD_MONEDA <> v_mon_local
       AND ESTADO = 'N'
       AND a.COD_MODULO = b.COD_MODULO
       AND A.COD_MODULO in (3,4)
       and b.cod_transaccion = 9603
       AND a.COD_MODALIDAD = b.COD_MODALIDAD
       AND a.COD_TRANSACCION = b.COD_TRANSACCION
       AND (COD_TIP_ASIENTO IS NOT NULL OR COD_TIP_ASIENTO2 IS NOT NULL)
       AND BATCH = 'B'
       --------------------------------------------------------
       AND EXISTS (SELECT 0 FROM CB_RUBROS X, GE_TIP_ASIENTOS c
                    WHERE c.COD_TIP_ASIENTO in (b.COD_TIP_ASIENTO, b.cod_tip_asiento2)
                      AND TIP_MOVIMIENTO = 'C'
                      AND c.COD_MONEDA = a.COD_MONEDA
                      AND X.COD_RUBRO(+) = C.COD_RUBRO
                      AND ((SUBSTR(C.COD_RUBRO,-2,2) IN ('98','99')) OR
                           (X.COD_MONEDA = v_mon_local) or
                           (SUBSTR(C.COD_RUBRO,1,2) = '24'))
                   )
      and a.COD_MODULO = p_cod_modulo
      and cod_oficina = p_cod_oficina
      and COD_MONEDA = p_cod_moneda
      and NVL(MONTO,0) <> 0;      
     
      
BEGIN
   insert into lc_bol_automaticos_res
         (fecha, hora, cod_usuario, monto, cod_moneda, cod_oficina, cod_Tra_padre,
          cod_transaccion, nro_documento, cod_mod_padre, cod_modalidad,
          concepto, cotizacion, mto_equ_local,cod_tip_ope_cambio,
          cod_bco_central, cod_mad_padre, cod_modulo, referencia)
   values(rp_rpoca.fecha, rp_rpoca.hora, rp_rpoca.cod_usuario, rp_rpoca.monto,
          rp_rpoca.cod_moneda, rp_rpoca.cod_oficina, rp_rpoca.cod_Tra_padre,
          rp_rpoca.cod_transaccion, rp_rpoca.nro_documento, rp_rpoca.cod_mod_padre,
          rp_rpoca.cod_modalidad, rp_rpoca.concepto, rp_rpoca.cotizacion,
          rp_rpoca.mto_equ_local, rp_rpoca.cod_tip_ope_cambio,rp_rpoca.cod_bco_central,
          rp_rpoca.Cod_Mad_Padre, rp_rpoca.cod_modulo, rp_rpoca.referencia);

   if rp_rpoca.referencia = 'VTA_DEV_AHORROS' then
      --- PR_PRO_DEV_AHORROS
      for i in c_dev_ahorros (rp_rpoca.fecha,
                              rp_rpoca.cod_moneda,
                              g_cod_modalidad,
                              rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, nro_documento, monto, nro_cuenta, referencia)
         values(rp_rpoca.fecha, rp_rpoca.nro_documento,
                i.mto_interes, i.nro_cuenta, rp_rpoca.referencia);
      end loop;
   elsif rp_rpoca.referencia = 'COM_DEV_PRESTAMOS' then
      --- PR_PRO_DEV_PRESTAMOS
      for i in c_dev_prestamos (rp_rpoca.fecha,
                                rp_rpoca.cod_moneda,
                                g_cod_modalidad,
                                rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, nro_documento, monto, nro_cuenta, referencia)
         values(rp_rpoca.fecha, rp_rpoca.nro_documento,
                i.MTO_DEV_ACTUAL, i.nro_cuenta, rp_rpoca.referencia);
      end loop;
   --- PR_PRO_VENTAS
   elsif rp_rpoca.referencia = 'VTA_OPE_GEN_OTROS' then
      for i in c_vta_ope_GEN_otros (rp_rpoca.cod_moneda,
                         g_cod_modulo,
                         rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, nro_documento, monto,
                fec_movimiento, hora, cod_usuario, nro_secuencia, referencia)
         values(rp_rpoca.fecha, rp_rpoca.nro_documento, i.monto,
                i.fecha, i.hora, i.cod_usuario, i.nro_secuencia,
                rp_rpoca.referencia);
      end loop;
   elsif rp_rpoca.referencia = 'VTA_OPE_CTE_PREVISION' then
      for i in c_VTA_OPE_CTE_PREVISION (rp_rpoca.cod_moneda,
                         g_cod_modulo,
                         rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, nro_documento, monto,
                fec_movimiento, hora, cod_usuario, nro_secuencia, referencia)
         values(rp_rpoca.fecha, rp_rpoca.nro_documento, i.monto,
                i.fecha, i.hora, i.cod_usuario, i.nro_secuencia,
                rp_rpoca.referencia);
      end loop;
   elsif rp_rpoca.referencia = 'VTA_OPE_CTE_OTROS' then
      for i in c_vta_ope_CTE_OTROS (rp_rpoca.cod_moneda,
                         g_cod_modulo,
                         rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, nro_documento, monto,
                fec_movimiento, hora, cod_usuario, nro_secuencia, referencia)
         values(rp_rpoca.fecha, rp_rpoca.nro_documento, i.monto,
                i.fecha, i.hora, i.cod_usuario, i.nro_secuencia,
                rp_rpoca.referencia);
      end loop;
   elsif rp_rpoca.referencia = 'VTA_OPE_PRE_PREVISION' then
      for i in c_VTA_OPE_PRE_PREVISION (rp_rpoca.cod_moneda,
                         g_cod_modulo,
                         rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, nro_documento, monto,
                fec_movimiento, hora, cod_usuario, nro_secuencia, referencia)
         values(rp_rpoca.fecha, rp_rpoca.nro_documento, i.monto,
                i.fecha, i.hora, i.cod_usuario, i.nro_secuencia,
                rp_rpoca.referencia);
      end loop;
   elsif rp_rpoca.referencia = 'VTA_OPE_PRE_OTROS' then
      for i in c_vta_ope_PRE_OTROS (rp_rpoca.cod_moneda,
                         g_cod_modulo,
                         rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, nro_documento, monto,
                fec_movimiento, hora, cod_usuario, nro_secuencia, referencia)
         values(rp_rpoca.fecha, rp_rpoca.nro_documento, i.monto,
                i.fecha, i.hora, i.cod_usuario, i.nro_secuencia,
                rp_rpoca.referencia);
      end loop;
   elsif rp_rpoca.referencia = 'VTA_APU_MASIVO' then
      for i in c_vta_apuntes (rp_rpoca.cod_moneda,
                              g_cod_modulo,
                              rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, nro_documento, monto,
                fec_movimiento, hora, cod_usuario, nro_secuencia, referencia)
         values(rp_rpoca.fecha, rp_rpoca.nro_documento, i.monto,
                i.fecha, i.hora, i.cod_usuario, i.nro_secuencia,
                rp_rpoca.referencia);
      end loop;
   elsif rp_rpoca.referencia = 'VTA_APU_INTERMONEDA' then
      for i in c_vta_internas (rp_rpoca.cod_moneda,
                               g_cod_modulo,
                               rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, nro_documento, monto,
                fec_movimiento, hora, cod_usuario, nro_secuencia, referencia)
         values(rp_rpoca.fecha, rp_rpoca.nro_documento, i.monto,
                i.fecha, i.hora, i.cod_usuario, i.nro_secuencia,
                rp_rpoca.referencia);
      end loop;
   --- PR_PRO_COMPRAS
   elsif rp_rpoca.referencia = 'COM_OPE_PRE_OTROS' then
      for i in c_COM_OPE_PRE_OTROS (rp_rpoca.cod_moneda,
                          g_cod_modulo,
                          rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, nro_documento, monto,
                fec_movimiento, hora, cod_usuario, nro_secuencia, referencia)
         values(rp_rpoca.fecha, rp_rpoca.nro_documento, i.monto,
                i.fecha, i.hora, i.cod_usuario, i.nro_secuencia,
                rp_rpoca.referencia);
      end loop;
   elsif rp_rpoca.referencia = 'COM_OPE_PRE_PREVISION' then
      for i in c_COM_OPE_PRE_PREVISION (rp_rpoca.cod_moneda,
                          g_cod_modulo,
                          rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, nro_documento, monto,
                fec_movimiento, hora, cod_usuario, nro_secuencia, referencia)
         values(rp_rpoca.fecha, rp_rpoca.nro_documento, i.monto,
                i.fecha, i.hora, i.cod_usuario, i.nro_secuencia,
                rp_rpoca.referencia);
      end loop;
   elsif rp_rpoca.referencia = 'COM_OPE_GEN_OTROS' then
      for i in c_COM_OPE_GEN_OTROS (rp_rpoca.cod_moneda,
                          g_cod_modulo,
                          rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, nro_documento, monto,
                fec_movimiento, hora, cod_usuario, nro_secuencia, referencia)
         values(rp_rpoca.fecha, rp_rpoca.nro_documento, i.monto,
                i.fecha, i.hora, i.cod_usuario, i.nro_secuencia,
                rp_rpoca.referencia);
      end loop;
   elsif rp_rpoca.referencia = 'COM_OPE_CTE_PREVISION' then
      for i in c_COM_OPE_CTE_PREVISION (rp_rpoca.cod_moneda,
                          g_cod_modulo,
                          rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, nro_documento, monto,
                fec_movimiento, hora, cod_usuario, nro_secuencia, referencia)
         values(rp_rpoca.fecha, rp_rpoca.nro_documento, i.monto,
                i.fecha, i.hora, i.cod_usuario, i.nro_secuencia,
                rp_rpoca.referencia);
      end loop;
   elsif rp_rpoca.referencia = 'COM_OPE_CTE_OTROS' then
      for i in c_COM_OPE_CTE_OTROS (rp_rpoca.cod_moneda,
                          g_cod_modulo,
                          rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, nro_documento, monto,
                fec_movimiento, hora, cod_usuario, nro_secuencia, referencia)
         values(rp_rpoca.fecha, rp_rpoca.nro_documento, i.monto,
                i.fecha, i.hora, i.cod_usuario, i.nro_secuencia,
                rp_rpoca.referencia);
      end loop;
   elsif rp_rpoca.referencia = 'COM_PRE_GENERICA' then
      for i in c_pre_genericas (rp_rpoca.cod_moneda,
                                g_cod_modulo,
                                rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, nro_documento, monto,
                fec_movimiento, hora, cod_usuario, nro_secuencia, referencia)
         values(rp_rpoca.fecha, rp_rpoca.nro_documento, i.monto,
                i.fecha, i.hora, i.cod_usuario, i.nro_secuencia,
                rp_rpoca.referencia);
      end loop;
   elsif rp_rpoca.referencia = 'COM_APU_MASIVO' then
      for i in c_com_apuntes (rp_rpoca.cod_moneda,
                              g_cod_modulo,
                              rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, nro_documento, monto,
                fec_movimiento, hora, cod_usuario, nro_secuencia, referencia)
         values(rp_rpoca.fecha, rp_rpoca.nro_documento, i.monto,
                i.fecha, i.hora, i.cod_usuario, i.nro_secuencia,
                rp_rpoca.referencia);
      end loop;
   elsif rp_rpoca.referencia in ('COM_ATM_EXTERIOR','COM_SIPAP',         -- PR_PRO_VTA_CLIENTES
                                 'VTA_REV_ATM_EXTERIOR','VTA_REV_SIPAP',
                                 'VTA_ATM_EXTERIOR','VTA_SIPAP',         -- PR_PRO_COM_CLIENTES
                                 'COM_REV_ATM_EXTERIOR','COM_REV_SIPAP')
         then
      insert into lc_bol_automaticos_det
            (fecha, nro_documento, monto, nro_cuenta, referencia)
      values(rp_rpoca.fecha, rp_rpoca.nro_documento,
             rp_rpoca.monto, g_nro_cuenta, rp_rpoca.referencia);
   elsif rp_rpoca.referencia = 'COM_DEV_ACT_MESA' then
      --- PR_PRO_DEV_MESA
      for i in c_dev_mesa_act (rp_rpoca.fecha,
                               rp_rpoca.cod_moneda,
                               g_cod_modalidad,
                               rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, nro_documento, monto, nro_cuenta, referencia)
         values(rp_rpoca.fecha, rp_rpoca.nro_documento,
                i.MTO_DEV_ACTUAL, i.nro_cuenta, rp_rpoca.referencia);
      end loop;
   elsif rp_rpoca.referencia = 'VTA_DEV_PAS_MESA' then
      for i in c_dev_mesa_pas (rp_rpoca.fecha,
                               rp_rpoca.cod_moneda,
                               g_cod_modalidad,
                               rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, nro_documento, monto, nro_cuenta, referencia)
         values(rp_rpoca.fecha, rp_rpoca.nro_documento,
                i.MTO_DEV_ACTUAL, i.nro_cuenta, rp_rpoca.referencia);
      end loop;
   --SDRES4COVI-81 - Resolución 4 - Previsiones Constitución y Diferimiento Productos RES04   
   elsif rp_rpoca.referencia = 'COM_OPE_PRE_RES4' then
      for i in c_comp_prev_resol4 (rp_rpoca.cod_moneda,
                                   rp_rpoca.cod_modulo,
                                   rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, fec_movimiento,nro_documento, monto, nro_cuenta, referencia)
         values(rp_rpoca.fecha, rp_rpoca.fecha, rp_rpoca.nro_documento,
                i.monto, i.nro_cuenta, rp_rpoca.referencia);
      end loop;
   elsif rp_rpoca.referencia = 'VTA_OPE_PRE_RES4' then
      for i in c_vta_pre_res4 (rp_rpoca.cod_moneda,
                               rp_rpoca.cod_modulo,
                               rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, fec_movimiento,hora, nro_secuencia, nro_documento, monto, nro_cuenta, referencia)
         values(rp_rpoca.fecha, rp_rpoca.fecha, rp_rpoca.hora,  i.nro_secuencia, rp_rpoca.nro_documento,
                i.monto, i.nro_cuenta, rp_rpoca.referencia);
      end loop;            
   --SDRES4COVI-81 - Resolución 4 - Previsiones Constitución y Diferimiento Productos RES04      
   elsif rp_rpoca.referencia = 'COM_MOV_RET_INR' then
      for i in c_comp_mov_ret_inr (rp_rpoca.cod_moneda,
                                   rp_rpoca.cod_modulo,
                                   rp_rpoca.cod_oficina) loop
         insert into lc_bol_automaticos_det
               (fecha, fec_movimiento,hora, nro_secuencia, nro_documento, monto, nro_cuenta, referencia)
         values(rp_rpoca.fecha, rp_rpoca.fecha, rp_rpoca.hora,  i.nro_secuencia, rp_rpoca.nro_documento,
                i.monto, i.nro_cuenta, rp_rpoca.referencia);
      end loop;            
   end if;

END;

-- CNFLPCAM-1 -- CN: 11/2015 --
-- Verificación del Límite de la Posición de Cambios--
/* En este procedimiento se realizará la Verificación del Límite de la Posición de Cambios,
   y de superarse, se generará una boleta inversa y se enviará un mail de alerta a un grupo de correos predefinido.
   En este proceso se realizará además la verificación de los valores y vigencia de parámetros de los
   Límites de Sobre Compra o Sobre Venta y se generará un mail de alerta al grupo de correos predefinido,
   en caso de que el último registrado no esté registrado como vigente a la fecha actual o no se encuentre ningún registro de estos parámetros.
   Este proceso se ejecutará en el Cierre Operativo Diario incluido en el proceso de Cierre de Cambios. */
 PROCEDURE PR_VER_LIM_POS_CAMBIOS IS
   v_fec_actual date := pag_cal.fu_obt_fec_actual(7);
   -- Cursor para obtener el Total de Compras y el Total de Ventas de Divisas intra día.
      cursor cur_intdia is
     select sum(x.compra_gs) mto_compra,
            sum(x.venta_gs) mto_venta
       from (
        -- Posición Spot
          select sum(decode (a.COD_MAD_PADRE,  71 , round(nvl(monto,0)*pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual),fue_dec_mon_local),0)) compra_gs,
                 sum(decode (a.COD_MAD_PADRE,  72 , round(nvl(monto,0)*pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual),fue_dec_mon_local),0)) venta_gs
            from ge_movimientos a, lc_tip_operaciones b
           where a.cod_tip_ope_cambio = b.cod_tip_operacion
             and a.fecha = v_fec_actual
             and a.reversado = 'N'
             and a.estado = 'N'
             and a.cod_mod_padre = 7 -- módulo -- 7 = cambios
             and ( (cod_mad_padre in (71, 72) and nro_secuencia in (1))
                  or (cod_mad_padre in (73,74) /*and nro_secuencia in (1,2)*/ ) )
             and a.cod_tip_ope_cambio is not null
             and b.afe_posicion != 'N'
             and a.cod_moneda != pag_gen.fu_obt_mon_local
             and not exists (select 1 -- se excluyen Liquidación de Full Delivery Forward (DYDMR-6062)
                               from ge_movimientos d,
                                    lc_tip_operaciones e,
                                    lc_ope_futuras f
                              where d.fecha = a.fecha
                                and d.hora = a.hora
                                and d.cod_usuario = a.cod_usuario
                                and d.nro_secuencia = a.nro_secuencia
                                and d.cod_tip_ope_cambio = e.cod_tip_operacion
                                and e.afe_ope_futura = 'S'
                                and d.cod_moneda != pag_gen.fu_obt_mon_local
                                and f.cod_tip_referencia = d.cod_ref_cambio
                                and f.nro_referencia = d.nro_documento2
                                and f.estado = 'L'
                                and d.reversado = 'N')
        UNION ALL
        -- Operaciones Futuras
        -- Tomar las activas en la fecha
          select a.compra_gs,
                 a.venta_gs
            from lv_pos_ope_futuras a ) x;

   -- Cursor para obtener el Total de Compras y el Total de Ventas de Divisas
   cursor cur_datos is
     select sum(x.compra_gs) mto_compra,
            sum(x.venta_gs) mto_venta
       from (
        -- Posición Inicial
          select sum(decode(a.tip_posicion, 'E', (a.mto_efe_compra * pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)),
                                            'O', (a.mto_nef_compra * pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)) )) compra_gs,
                 sum(decode(a.tip_posicion, 'E', (a.mto_efe_venta * pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)),
                                            'O', (a.mto_nef_venta * pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)) )) venta_gs
            from lc_sal_posiciones a
        UNION ALL
        -- Posición Spot
        -- Tomar el valor de conversion de la moneda a la fecha
          select sum(decode(b.cod_mad_hijo,71,(a.monto * pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)),0)) compra_gs, -- 71 = compra
                 sum(decode(b.cod_mad_hijo,72,(a.monto * pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)),0)) venta_gs -- 72 = venta*/
            from ge_movimientos a, lc_tip_operaciones b
           where a.cod_tip_ope_cambio = b.cod_tip_operacion
             and a.fecha = v_fec_actual
             and a.reversado = 'N'
             and a.estado = 'N'
             and a.cod_mod_padre = 7 -- módulo -- 7 = cambios
             and ( (cod_mad_padre in (71, 72) and nro_secuencia in (1))
                  or (cod_mad_padre in (73,74) /*and nro_secuencia in (1,2)*/ ) )
             and a.cod_tip_ope_cambio is not null
             and b.afe_posicion != 'N'
             and a.cod_moneda != pag_gen.fu_obt_mon_local
        UNION ALL
        -- Operaciones Futuras
        -- Tomar el valor de conversion de la moneda a la fecha
          select sum(decode(a.cod_mad_transaccion,71,(a.monto * pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)),0)) compra_gs,
                 sum(decode(a.cod_mad_transaccion,72,(a.monto * pag_gen.fu_obt_cotizacion(a.cod_moneda, v_fec_actual)),0)) venta_gs
            from lc_ope_futuras a
           where a.fec_operacion <= v_fec_actual
             and a.estado in ('N'/*, 'X', 'I'*/)  ) x;  -- para el balance se toma solo N
   --
   v_hora               ge_movimientos.hora%type := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
   v_monto              ge_movimientos.monto%type;
   v_tot_mon_local      ge_movimientos.monto%type;
   v_tot_compra         ge_movimientos.monto%type;
   v_tot_venta          ge_movimientos.monto%type;
   v_tot_compra_usd     ge_movimientos.monto%type;
   v_tot_venta_usd      ge_movimientos.monto%type;
   v_cotizacion         ge_movimientos.cotizacion%type;
   v_cod_moneda         ge_movimientos.cod_moneda%type;
   v_mon_local          ge_movimientos.cod_moneda%type;
   v_cod_modulo         ge_movimientos.cod_modulo%type;
   v_cod_modalidad      ge_movimientos.cod_modalidad%type;
   v_cod_persona        ge_movimientos.cod_persona%type;
   v_concepto           ge_movimientos.concepto%type;
   v_referencia         ge_movimientos.referencia%type;
   v_nro_operacion      ge_movimientos.nro_documento%type;
   v_cod_oficina        ge_movimientos.cod_oficina%type;
   v_cod_tra_padre      ge_movimientos.cod_tra_padre%type;
   v_cod_transaccion    ge_movimientos.cod_transaccion%type;
   v_cod_rubro          ge_movimientos.cod_rubro%type;
   v_tip_mov_rubro      ge_movimientos.tip_mov_rubro%type;
   v_nro_cuenta         ge_movimientos.nro_cuenta%type;
   r_gmovi              ge_movimientos%rowtype;
   v_cod_tip_operacion  lc_tip_operaciones.cod_tip_operacion%type;
   v_cod_tip_ope_bcp    lc_tip_operaciones.cod_tip_ope_bcp%type;
   v_tip_ope_bcp        lc_tip_operaciones.cod_tip_ope_bcp%type;
   v_mto_lim_sob_compra lc_par_lim_pos_cambios.mto_lim_sob_compra%type;
   v_mto_lim_sob_venta  lc_par_lim_pos_cambios.mto_lim_sob_venta%type;
   v_lim_sob_com_diario lc_par_lim_pos_cambios.lim_sob_com_diario%type;
   v_lim_sob_vta_diario lc_par_lim_pos_cambios.lim_sob_vta_diario%type;
   v_dir_correo_ent     ge_log_mail.dir_correo%type := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--fug_obt_dir_correo; --'bbvanet@bbva.com.py'
   v_dir_correo         ge_par_dinamicos.val_parametro%type;
   v_mensaje            ge_log_mail.mensaje%type;
   v_det_error          ge_log_mail.det_error%type;
   v_hor_inicio         ge_log_mail.hor_inicio%type;
   v_hor_fin            ge_log_mail.hor_fin%type;
   v_asunto             varchar2(500);
   v_redondeo           number;
   v_redondeo_loc       number;
   v_gen_movimiento     varchar2(1) := 'N';
   v_env_alerta         varchar2(1) := 'N';
   --
   -- Procedimiento para obtener el monto límite de sobre compra y sobre venta
   procedure lp_obt_mto_limite( p_mto_lim_sob_compra in out lc_par_lim_pos_cambios.mto_lim_sob_compra%type,
                                p_mto_lim_sob_venta  in out lc_par_lim_pos_cambios.mto_lim_sob_venta%type,
                                p_lim_sob_com_diario in out lc_par_lim_pos_cambios.lim_sob_com_diario%type,
                                p_lim_sob_vta_diario in out lc_par_lim_pos_cambios.lim_sob_vta_diario%type
                               ) is
     -- Fecha vigente --
     cursor cur_par is
       select a.codigo, a.mto_lim_sob_compra, a.mto_lim_sob_venta,
              a.lim_sob_com_diario, a.lim_sob_vta_diario
         from lc_par_lim_pos_cambios a
        where v_fec_actual between a.fec_ini_vigencia and a.fec_fin_vigencia
        order by 1 desc;
     -- Fecha no vigente --
     cursor cur_par_fec is
       select a.codigo, a.mto_lim_sob_compra, a.mto_lim_sob_venta,
              a.lim_sob_com_diario, a.lim_sob_vta_diario
         from lc_par_lim_pos_cambios a
        where a.fec_fin_vigencia = ( select max(a.fec_fin_vigencia)
                                       from lc_par_lim_pos_cambios a
                                      where a.fec_fin_vigencia < v_fec_actual )
        order by 1 desc;
     v_codigo  lc_par_lim_pos_cambios.codigo%type;
   begin
     -- Fecha vigente --
     if cur_par%isopen then
       close cur_par;
     end if;
     open cur_par;
       loop
         fetch cur_par
          into v_codigo, p_mto_lim_sob_compra, p_mto_lim_sob_venta,
               p_lim_sob_com_diario, p_lim_sob_vta_diario;
          --exit when cur_par%notfound;
          exit;
      end loop;
      if cur_par%isopen then
        close cur_par;
      end if;

      -- Si no encuentra uno vigente --
      if p_mto_lim_sob_compra is null or p_mto_lim_sob_venta is null then
        v_env_alerta := 'S';
        v_mensaje     := 'Error en la Verificación de Límites de Posición de Cambios.'||chr(10)||
                         'No se ha encontrado ningún registro con fecha de vigencia a la fecha actual en la tabla de parámetros.'||chr(10)||
                         'Se utiliza el de fecha de finalización de vigencia mas reciente.';
        if cur_par_fec%isopen then
          close cur_par_fec;
        end if;
        open cur_par_fec;
          loop
            fetch cur_par_fec
             into v_codigo, p_mto_lim_sob_compra, p_mto_lim_sob_venta,
                  p_lim_sob_com_diario, p_lim_sob_vta_diario;
             --exit when cur_par_fec%notfound;
             exit;
          end loop;
        if cur_par_fec%isopen then
          close cur_par_fec;
        end if;
      end if;
   exception
     when others then
       Raise_application_error(-20000, 'Error al obtener datos de Parámetros de Límites de Posición de Cambios');
   end;
   --
   -- Datos del Tipo de Operacion --
   procedure lp_obt_dat_operacion( p_cod_tip_operacion in lc_tip_operaciones.cod_tip_operacion%type,
                                   p_cod_cod_transaccion in out lc_tip_operaciones.cod_transaccion%type,
                                   p_cod_tip_ope_bcp in out lc_tip_operaciones.cod_tip_ope_bcp%type
                                  ) is
   begin
     select cod_transaccion, cod_tip_ope_bcp
       into p_cod_cod_transaccion, p_cod_tip_ope_bcp
       from lc_tip_operaciones a
      where a.cod_tip_operacion = p_cod_tip_operacion;
   exception
     when others then
       Raise_application_error(-20000, 'Error al obtener datos del Tipo de Operacion '||p_cod_tip_operacion);
   end;
   --
  BEGIN
    -- Límite Posición de Cambio Intra-día
    v_fec_actual := pag_cal.fu_obt_fec_actual(7);
    if cur_intdia%isopen then
      close cur_intdia;
    end if;
    open cur_intdia;
    loop
      fetch cur_intdia
       into v_tot_compra, v_tot_venta;
      exit when cur_intdia%notfound;
    end loop;
    if cur_intdia%isopen then
        close cur_intdia;
    end if;

    -- Realizar la conversión a Dólares --
    v_cod_moneda      := pag_gen.fu_obt_mon_fuerte;
    v_cotizacion      := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
    v_redondeo        := nvl(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_cod_moneda),2);
    v_tot_compra_usd  := round( nvl(v_tot_compra,0) / v_cotizacion, v_redondeo);
    v_tot_venta_usd   := round( nvl(v_tot_venta,0) / v_cotizacion, v_redondeo);

    -- Obtener el Monto Límite de Sobre Compra y Sobre Venta
    lp_obt_mto_limite(v_mto_lim_sob_compra,v_mto_lim_sob_venta,
                      v_lim_sob_com_diario, v_lim_sob_vta_diario);

    -- No se ha cargado ningun registro en la tabla de parámetros
    if v_lim_sob_com_diario is null or v_lim_sob_vta_diario is null then
      v_env_alerta := 'S';
      v_mensaje     := 'Error en la Verificación de Límites de Posición de Cambios Intra día.'||chr(10)||
                       'No se ha encontrado ningún registro en la tabla de parámetros.'||chr(10)||
                       'Para registrarlo debe ingresar al Sistema ITGF, en el menú de Cambios --> Configuración --> Parámetros Lim. Pos. Cambios.'||chr(10)||
                       'No se realiza el proceso de Verificación de Límites de Cambios.';
    else
      -- Si el Total de Compras supera al Total de Ventas
      if v_tot_compra_usd > v_tot_venta_usd then
        -- Monto = Total de Compras menos el Total de Ventas
        v_monto := round(v_tot_compra_usd - v_tot_venta_usd, v_redondeo);
        -- Si el Total de Compras menos el Total de Ventas es mayor al Monto Límite de Sobre Compra
        -- se registrará una Venta de Divisas de la Moneda Dólares por el Total de Compras menos el Total de Ventas
        -- imputando al rubro predefinido para la Moneda
        if v_monto > v_lim_sob_com_diario then
          v_monto := round(v_monto - v_lim_sob_com_diario,v_redondeo);
          v_gen_movimiento     := 'S';
          v_cod_modalidad      := 72;     -- 72 = VENTA
          v_cod_tip_operacion  := 31;     -- 31 = VENTA CUENTA CONTABLE
          --v_cod_tip_ope_bcp    := 'B27';  -- B27 = OTROS SERVICIOS
          --v_cod_tra_padre      := 277;
          lp_obt_dat_operacion(v_cod_tip_operacion,v_cod_tra_padre,v_cod_tip_ope_bcp);
          v_cod_rubro     := fug_obt_pardinamico('COD_RUB_LIM_POS_CAMBIOS',null,null,v_cod_moneda);
          v_tip_mov_rubro := 'C';
          v_mensaje := 'Se ha generado una Boleta de Venta de Divisas por haberse superado el monto límite intra día, de sobre compra establecido.';
        else
          v_gen_movimiento := 'N';
        end if;
      -- Si el Total de Ventas supera al Total de Compras
      elsif v_tot_venta_usd > v_tot_compra_usd then
        v_monto := round(v_tot_venta_usd - v_tot_compra_usd, v_redondeo);
        -- Si el Total de Ventas menos el Total de Compras es mayor al Monto Límite de Sobre Venta
        -- se registrará una Compra de Divisas de la Moneda Dólares por el Total de Ventas menos el Total de Compras
        -- imputando al rubro predefinido para la Moneda
        if v_monto > v_lim_sob_vta_diario then
          v_monto := round(v_monto - v_lim_sob_vta_diario,v_redondeo);
          v_gen_movimiento     := 'S';
          v_cod_modalidad      := 71;     -- 71 = COMPRA
          v_cod_tip_operacion  := 17;     -- 17 = COMPRA CUENTA CONTABLE
          --v_cod_tip_ope_bcp    := 'A19';  -- A19 = OTROS
          --v_cod_tra_padre      := 261;
          lp_obt_dat_operacion(v_cod_tip_operacion,v_cod_tra_padre,v_cod_tip_ope_bcp);
          v_cod_rubro     := fug_obt_pardinamico('COD_RUB_LIM_POS_CAMBIOS',null,null,v_cod_moneda);
          v_tip_mov_rubro := 'D';
          v_mensaje := 'Se ha generado una Boleta de Compra de Divisas por haberse superado el monto límite intra día, de sobre venta establecido.';
        else
          v_gen_movimiento := 'N';
        end if;
      end if;

      -- Generar el movimiento --
      if nvl(v_gen_movimiento,'N') = 'S' then
        v_hora        := to_char(sysdate,'HH24:MI:SS');
        v_hora        := fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');
        v_cod_oficina := nvl(fug_obt_pardinamico('COD_OFI_POS_CAMBIOS'),31);
        v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, v_cod_modalidad, v_cod_moneda, v_cod_oficina)+1;
        prg_act_par_dinamico('NRO_RECIBO',7, v_cod_modalidad, v_cod_moneda, v_cod_oficina, v_nro_operacion);
        v_mon_local := pag_gen.fu_obt_mon_local;
        v_redondeo_loc    := nvl(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_mon_local),0);
        v_tot_mon_local   := round(nvl(v_cotizacion,0) * v_monto, v_redondeo_loc);
        v_cod_persona     := LF_OBT_PER_ENTIDAD;
        v_concepto        := 'BOLETAS DE CAMBIOS INTRA DIA - PROCESO NOCTURNO';
        v_referencia      := 'BOL.PRO.NOC.INTRADIA'; -- varchar2(20)
        v_cod_modulo      := 7; -- 7 = CAMBIOS
        v_cod_transaccion := v_cod_tra_padre;

        --- genera movimiento ---
        r_gmovi.cod_usuario     := user;
        r_gmovi.hora            := v_hora;
        r_gmovi.nro_secuencia   := 1; -- FIJO 1 para que tome los reportes de cambios
        r_gmovi.cod_modulo      := v_cod_modulo;
        r_gmovi.cod_modalidad   := v_cod_modalidad;
        r_gmovi.cod_oficina     := v_cod_oficina;
        r_gmovi.nro_cuenta      := null;
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_transaccion := v_cod_transaccion;
        r_gmovi.nro_documento   := v_nro_operacion;
        r_gmovi.nro_documento2  := null;
        r_gmovi.monto           := v_monto;
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := v_cod_oficina;
        r_gmovi.reversado       := 'N';
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.cod_mod_padre   := v_cod_modulo;
        r_gmovi.cod_mad_padre   := v_cod_modalidad;
        r_gmovi.concepto        := v_concepto;
        r_gmovi.cotizacion      := v_cotizacion;
        r_gmovi.mto_equ_local   := v_tot_mon_local;
        r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
        r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
        r_gmovi.referencia      := v_referencia;
        r_gmovi.cod_persona     := v_cod_persona;
        r_gmovi.cod_rubro       := v_cod_rubro;
        r_gmovi.tip_mov_rubro   := v_tip_mov_rubro;
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

        v_mensaje := v_mensaje||chr(10)||
                     'Datos de la operación'||chr(10)||
                     'Fecha: '||to_char(v_fec_actual,'dd/mm/yyyy')||chr(10)||
                     'Nro. Operación: '||v_nro_operacion||chr(10)||
                     'Transaccion: '||v_cod_transaccion||chr(10)||
                     'Usuario: '||r_gmovi.cod_usuario||chr(10)||
                     'Hora: '||v_hora||chr(10)||
                     'Concepto: '||v_concepto||chr(10)||
                     'Monto: '||to_char(v_monto,'999G999G999G999D00')||' '||v_cod_moneda;

        --- genera movimiento x persona, para listados ---
        v_cod_transaccion       := 760;
        --asigna cta bolsa
        v_nro_cuenta := fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_oficina);
        r_gmovi.cod_usuario     := user;
        r_gmovi.hora            := v_hora;
        r_gmovi.nro_secuencia   := 2; -- FIJO para que tome los reportes de cambios
        r_gmovi.cod_modulo      := v_cod_modulo;
        r_gmovi.cod_modalidad   := 70; --v_cod_modalidad;
        r_gmovi.cod_oficina     := pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina);
        r_gmovi.nro_cuenta      := v_nro_cuenta;
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_transaccion := v_cod_transaccion;
        r_gmovi.nro_documento   := v_nro_operacion;
        r_gmovi.nro_documento2  := LF_OBT_PER_ENTIDAD;
        r_gmovi.monto           := 0;
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := v_cod_oficina;
        r_gmovi.reversado       := 'N';
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.cod_mod_padre   := v_cod_modulo;
        r_gmovi.cod_mad_padre   := v_cod_modalidad;
        r_gmovi.concepto        := v_concepto;
        r_gmovi.cotizacion      := null;
        r_gmovi.mto_equ_local   := null;
        r_gmovi.cod_tip_ope_cambio := null;
        r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
        r_gmovi.referencia      := v_referencia;
        r_gmovi.cod_persona     := v_cod_persona;
        r_gmovi.cod_rubro       := null;
        r_gmovi.tip_mov_rubro   := null;
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

        -- Generar el Débito o Crédito en Cuenta Contable --
        --v_mon_local := pag_gen.fu_obt_mon_local;
        --v_cod_transaccion       := 842;  -- Modalidad 71=COMPRA CONTABLE CAMBIOS -- Modalidad 72=VENTA CONTABLE CAMBIOS
        if v_cod_modalidad = 71 then  -- 71 = COMPRA
          v_cod_tip_operacion := 4;
          --v_cod_tip_ope_bcp := null;
          --v_cod_transaccion := 741;
          lp_obt_dat_operacion(v_cod_tip_operacion,v_cod_transaccion,v_tip_ope_bcp);
          v_cod_rubro     := fug_obt_pardinamico('COD_RUB_LIM_POS_CAMBIOS',null,null,v_mon_local);
          v_tip_mov_rubro := 'C';
        elsif v_cod_modalidad = 72 then  -- 72 = VENTA
          v_cod_tip_operacion := 9;
          --v_cod_tip_ope_bcp := null;
          --v_cod_transaccion := 842;
          lp_obt_dat_operacion(v_cod_tip_operacion,v_cod_transaccion,v_tip_ope_bcp);
          v_cod_rubro     := fug_obt_pardinamico('COD_RUB_LIM_POS_CAMBIOS',null,null,v_mon_local);
          v_tip_mov_rubro := 'D';
        end if;

        r_gmovi.cod_usuario     := user;
        r_gmovi.hora            := v_hora;
        r_gmovi.nro_secuencia   := 3; -- FIJO
        r_gmovi.cod_modulo      := v_cod_modulo;
        r_gmovi.cod_modalidad   := v_cod_modalidad;
        r_gmovi.cod_oficina     := v_cod_oficina;
        r_gmovi.nro_cuenta      := null;
        r_gmovi.cod_moneda      := v_mon_local;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_transaccion := v_cod_transaccion;
        r_gmovi.nro_documento   := v_nro_operacion;
        r_gmovi.nro_documento2  := null;
        r_gmovi.monto           := v_tot_mon_local;
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := v_cod_oficina;
        r_gmovi.reversado       := 'N';
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.cod_mod_padre   := v_cod_modulo;
        r_gmovi.cod_mad_padre   := v_cod_modalidad;
        r_gmovi.concepto        := v_concepto;
        r_gmovi.cotizacion      := null;
        r_gmovi.mto_equ_local   := null;
        r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
        r_gmovi.cod_bco_central    := v_tip_ope_bcp;
        r_gmovi.referencia      := v_referencia;
        r_gmovi.cod_persona     := v_cod_persona;
        r_gmovi.cod_rubro       := v_cod_rubro;
        r_gmovi.tip_mov_rubro   := v_tip_mov_rubro;
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

        -- Actualizar la posicion --
        IF v_cod_modalidad = 72 THEN  /* ES UNA VENTA */
           --actualiza la posicion
           UPDATE LC_POSICIONES SET
                  MTO_VTA_NEF_ACT = NVL(MTO_VTA_NEF_ACT,0) + v_monto,
                  MTO_VTA_NEF_LOC = NVL(MTO_VTA_NEF_LOC,0) + v_tot_mon_local
           WHERE COD_TIP_OPE_BCP = v_cod_tip_ope_bcp
             AND COD_MONEDA = v_cod_moneda
             AND COD_OFI_CAMBIO = pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina);
          --inserta posicion si no existe
          IF SQL%NOTFOUND THEN
             INSERT INTO LC_POSICIONES
                 (COD_MONEDA, COD_TIP_OPE_BCP, COD_OFI_CAMBIO,
                  MTO_VTA_NEF_ACT, MTO_VTA_NEF_LOC)
             VALUES
                 (v_cod_moneda, v_cod_tip_ope_bcp,
                  pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina), v_monto,v_tot_mon_local);
          END IF;
        ELSE --es una compra
          --actualiza la posicion
          UPDATE LC_POSICIONES SET
                 MTO_COM_NEF_ACT = NVL(MTO_COM_NEF_ACT,0) + ABS(v_monto),
                 MTO_COM_NEF_LOC = NVL(MTO_COM_NEF_LOC,0) + ABS(v_tot_mon_local)
           WHERE COD_TIP_OPE_BCP = v_cod_tip_ope_bcp
             AND COD_MONEDA = v_cod_moneda
             AND COD_OFI_CAMBIO = pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina);
          --inserta posicion si no existe
          IF SQL%NOTFOUND THEN
             INSERT INTO LC_POSICIONES
                 (COD_MONEDA, COD_TIP_OPE_BCP, COD_OFI_CAMBIO,
                  MTO_COM_NEF_ACT, MTO_COM_NEF_LOC)
             VALUES
                 (v_cod_moneda, v_cod_tip_ope_bcp,
                  pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina), ABS(v_monto), ABS(v_tot_mon_local));
          END IF;
        END IF;
        -- Enviar mail --
        v_hor_inicio := to_char(sysdate, 'hh24:mi:ss');
        v_dir_correo := fug_obt_pardinamico('EMAIL_VER_LIM_POS_CAMBIOS');
        v_asunto     := 'Verificación de Límites de Posición de Cambios Intra día';
        if v_dir_correo is not null then
          begin
            prg_env_mail(v_dir_correo_ent, v_dir_correo, v_asunto, v_mensaje);
          exception
            when others then
              -- Si hay error al enviar mail se inserta en la tabla ge_log_mail
               v_mensaje     := v_mensaje||chr(10)||'Error al enviar mail.';
               v_det_error   := substr(sqlerrm, 1, 4000);
               v_hor_fin     := to_char(sysdate, 'hh24:mi:ss');
               INSERT INTO ge_log_mail
                  (fec_envio,cod_persona,dir_correo,mensaje,det_error,nro_cuenta,hor_inicio,hor_fin)
               VALUES
                  (v_fec_actual,v_cod_persona,v_dir_correo,v_mensaje,v_det_error,null,v_hor_inicio,v_hor_fin);
          end;
        end if;
      end if;
    end if;

    --Enviar alerta vía mail
    if nvl(v_env_alerta,'N') = 'S' then
      v_hor_inicio := to_char(sysdate, 'hh24:mi:ss');
      v_dir_correo := fug_obt_pardinamico('EMAIL_VER_LIM_POS_CAMBIOS');
      v_asunto     := 'Verificación de Límites de Posición de Cambios Intra día';
      if v_dir_correo is not null then
        begin
          prg_env_mail(v_dir_correo_ent, v_dir_correo, v_asunto, v_mensaje);
        exception
          when others then
            -- Si hay error al enviar mail se inserta en la tabla tm_mails
             v_mensaje     := v_mensaje||chr(10)||' Error al enviar mail. #LPC';
             v_det_error   := substr(sqlerrm, 1, 4000);
             v_cod_persona := LF_OBT_PER_ENTIDAD;
             v_hor_fin     := to_char(sysdate, 'hh24:mi:ss');
             INSERT INTO ge_log_mail
                (fec_envio,cod_persona,dir_correo,mensaje,det_error,nro_cuenta,hor_inicio,hor_fin)
             VALUES
                (v_fec_actual,v_cod_persona,v_dir_correo,v_mensaje,v_det_error,null,v_hor_inicio,v_hor_fin);
        end;
      end if;
    end if;
    v_tot_compra         := null;
    v_tot_venta          := null;
    v_mto_lim_sob_compra := null;
    v_mto_lim_sob_venta  := null;
    v_lim_sob_com_diario := null;
    v_lim_sob_vta_diario := null;
    v_gen_movimiento     := 'N';
    -- Fin intra día

    --**-----------------------------------------------------**--
    -- Obtener Total de Compras y Total de Ventas de Divisas --
    v_fec_actual := pag_cal.fu_obt_fec_actual(7);
    if cur_datos%isopen then
      close cur_datos;
    end if;
    open cur_datos;
    loop
      fetch cur_datos
       into v_tot_compra, v_tot_venta;
      exit when cur_datos%notfound;
    end loop;
    if cur_datos%isopen then
        close cur_datos;
    end if;

    -- Realizar la conversión a Dólares --
    v_cod_moneda      := pag_gen.fu_obt_mon_fuerte;
    v_cotizacion      := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
    v_redondeo        := nvl(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_cod_moneda),2);
    v_tot_compra_usd  := round( nvl(v_tot_compra,0) / v_cotizacion, v_redondeo);
    v_tot_venta_usd   := round( nvl(v_tot_venta,0) / v_cotizacion, v_redondeo);

    -- Obtener el Monto Límite de Sobre Compra y Sobre Venta
    lp_obt_mto_limite(v_mto_lim_sob_compra,v_mto_lim_sob_venta,
                      v_lim_sob_com_diario, v_lim_sob_vta_diario);

    -- No se ha cargado ningun registro en la tabla de parámetros
    if v_mto_lim_sob_compra is null or v_mto_lim_sob_venta is null then
      v_env_alerta := 'S';
      v_mensaje     := 'Error en la Verificación de Límites de Posición de Cambios.'||chr(10)||
                       'No se ha encontrado ningún registro en la tabla de parámetros.'||chr(10)||
                       'Para registrarlo debe ingresar al Sistema ITGF, en el menú de Cambios --> Configuración --> Parámetros Lim. Pos. Cambios.'||chr(10)||
                       'No se realiza el proceso de Verificación de Límites de Cambios.';
    else
      -- Si el Total de Compras supera al Total de Ventas
      if v_tot_compra_usd > v_tot_venta_usd then
        -- Monto = Total de Compras menos el Total de Ventas
        v_monto := round(v_tot_compra_usd - v_tot_venta_usd, v_redondeo);
        -- Si el Total de Compras menos el Total de Ventas es mayor al Monto Límite de Sobre Compra
        -- se registrará una Venta de Divisas de la Moneda Dólares por el Total de Compras menos el Total de Ventas
        -- imputando al rubro predefinido para la Moneda
        if v_monto > v_mto_lim_sob_compra then
          v_monto := round(v_monto - v_mto_lim_sob_compra,v_redondeo);
          v_gen_movimiento     := 'S';
          v_cod_modalidad      := 72;     -- 72 = VENTA
          v_cod_tip_operacion  := 31;     -- 31 = VENTA CUENTA CONTABLE
          --v_cod_tip_ope_bcp    := 'B27';  -- B27 = OTROS SERVICIOS
          --v_cod_tra_padre      := 277;
          lp_obt_dat_operacion(v_cod_tip_operacion,v_cod_tra_padre,v_cod_tip_ope_bcp);
          v_cod_rubro     := fug_obt_pardinamico('COD_RUB_LIM_POS_CAMBIOS',null,null,v_cod_moneda);
          v_tip_mov_rubro := 'C';
          v_mensaje := 'Se ha generado una Boleta de Venta de Divisas por haberse superado el monto límite de sobre compra establecido.';
        else
          v_gen_movimiento := 'N';
        end if;
      -- Si el Total de Ventas supera al Total de Compras
      elsif v_tot_venta_usd > v_tot_compra_usd then
        v_monto := round(v_tot_venta_usd - v_tot_compra_usd, v_redondeo);
        -- Si el Total de Ventas menos el Total de Compras es mayor al Monto Límite de Sobre Venta
        -- se registrará una Compra de Divisas de la Moneda Dólares por el Total de Ventas menos el Total de Compras
        -- imputando al rubro predefinido para la Moneda
        if v_monto > v_mto_lim_sob_venta then
          v_monto := round(v_monto - v_mto_lim_sob_venta,v_redondeo);
          v_gen_movimiento     := 'S';
          v_cod_modalidad      := 71;     -- 71 = COMPRA
          v_cod_tip_operacion  := 17;     -- 17 = COMPRA CUENTA CONTABLE
          --v_cod_tip_ope_bcp    := 'A19';  -- A19 = OTROS
          --v_cod_tra_padre      := 261;
          lp_obt_dat_operacion(v_cod_tip_operacion,v_cod_tra_padre,v_cod_tip_ope_bcp);
          v_cod_rubro     := fug_obt_pardinamico('COD_RUB_LIM_POS_CAMBIOS',null,null,v_cod_moneda);
          v_tip_mov_rubro := 'D';
          v_mensaje := 'Se ha generado una Boleta de Compra de Divisas por haberse superado el monto límite de sobre venta establecido.';
        else
          v_gen_movimiento := 'N';
        end if;
      end if;

      -- Generar el movimiento --
      if nvl(v_gen_movimiento,'N') = 'S' then
        v_hora        := to_char(sysdate,'HH24:MI:SS');
        v_hora        := fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');
        v_cod_oficina := nvl(fug_obt_pardinamico('COD_OFI_POS_CAMBIOS'),31);
        v_nro_operacion := fug_obt_lla_pardinamico('NRO_RECIBO', 7, v_cod_modalidad, v_cod_moneda, v_cod_oficina)+1;
        prg_act_par_dinamico('NRO_RECIBO',7, v_cod_modalidad, v_cod_moneda, v_cod_oficina, v_nro_operacion);
        v_mon_local := pag_gen.fu_obt_mon_local;
        v_redondeo_loc    := nvl(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_mon_local),0);
        v_tot_mon_local   := round(nvl(v_cotizacion,0) * v_monto, v_redondeo_loc);
        v_cod_persona     := LF_OBT_PER_ENTIDAD;
        v_concepto        := 'BOLETAS DE CAMBIOS - PROCESO NOCTURNO';
        v_referencia      := 'BOL.PROC.NOCTURNO';
        v_cod_modulo      := 7; -- 7 = CAMBIOS
        v_cod_transaccion := v_cod_tra_padre;

        --- genera movimiento ---
        r_gmovi.cod_usuario     := user;
        r_gmovi.hora            := v_hora;
        r_gmovi.nro_secuencia   := 1; -- FIJO 1 para que tome los reportes de cambios
        r_gmovi.cod_modulo      := v_cod_modulo;
        r_gmovi.cod_modalidad   := v_cod_modalidad;
        r_gmovi.cod_oficina     := v_cod_oficina;
        r_gmovi.nro_cuenta      := null;
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_transaccion := v_cod_transaccion;
        r_gmovi.nro_documento   := v_nro_operacion;
        r_gmovi.nro_documento2  := null;
        r_gmovi.monto           := v_monto;
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := v_cod_oficina;
        r_gmovi.reversado       := 'N';
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.cod_mod_padre   := v_cod_modulo;
        r_gmovi.cod_mad_padre   := v_cod_modalidad;
        r_gmovi.concepto        := v_concepto;
        r_gmovi.cotizacion      := v_cotizacion;
        r_gmovi.mto_equ_local   := v_tot_mon_local;
        r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
        r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
        r_gmovi.referencia      := v_referencia;
        r_gmovi.cod_persona     := v_cod_persona;
        r_gmovi.cod_rubro       := v_cod_rubro;
        r_gmovi.tip_mov_rubro   := v_tip_mov_rubro;
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

        v_mensaje := v_mensaje||chr(10)||
                     'Datos de la operación'||chr(10)||
                     'Fecha: '||to_char(v_fec_actual,'dd/mm/yyyy')||chr(10)||
                     'Nro. Operación: '||v_nro_operacion||chr(10)||
                     'Transaccion: '||v_cod_transaccion||chr(10)||
                     'Usuario: '||r_gmovi.cod_usuario||chr(10)||
                     'Hora: '||v_hora||chr(10)||
                     'Concepto: '||v_concepto||chr(10)||
                     'Monto: '||to_char(v_monto,'999G999G999G999D00')||' '||v_cod_moneda;

        --- genera movimiento x persona, para listados ---
        v_cod_transaccion       := 760;
        --asigna cta bolsa
        v_nro_cuenta := fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_oficina);
        r_gmovi.cod_usuario     := user;
        r_gmovi.hora            := v_hora;
        r_gmovi.nro_secuencia   := 2; -- FIJO para que tome los reportes de cambios
        r_gmovi.cod_modulo      := v_cod_modulo;
        r_gmovi.cod_modalidad   := 70; --v_cod_modalidad;
        r_gmovi.cod_oficina     := pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina);
        r_gmovi.nro_cuenta      := v_nro_cuenta;
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_transaccion := v_cod_transaccion;
        r_gmovi.nro_documento   := v_nro_operacion;
        r_gmovi.nro_documento2  := LF_OBT_PER_ENTIDAD;
        r_gmovi.monto           := 0;
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := v_cod_oficina;
        r_gmovi.reversado       := 'N';
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.cod_mod_padre   := v_cod_modulo;
        r_gmovi.cod_mad_padre   := v_cod_modalidad;
        r_gmovi.concepto        := v_concepto;
        r_gmovi.cotizacion      := null;
        r_gmovi.mto_equ_local   := null;
        r_gmovi.cod_tip_ope_cambio := null;
        r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
        r_gmovi.referencia      := v_referencia;
        r_gmovi.cod_persona     := v_cod_persona;
        r_gmovi.cod_rubro       := null;
        r_gmovi.tip_mov_rubro   := null;
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

        -- Generar el Débito o Crédito en Cuenta Contable --
        --v_mon_local := pag_gen.fu_obt_mon_local;
        --v_cod_transaccion       := 842;  -- Modalidad 71=COMPRA CONTABLE CAMBIOS -- Modalidad 72=VENTA CONTABLE CAMBIOS
        if v_cod_modalidad = 71 then  -- 71 = COMPRA
          v_cod_tip_operacion := 4;
          --v_cod_tip_ope_bcp := null;
          --v_cod_transaccion := 741;
          lp_obt_dat_operacion(v_cod_tip_operacion,v_cod_transaccion,v_tip_ope_bcp);
          v_cod_rubro     := fug_obt_pardinamico('COD_RUB_LIM_POS_CAMBIOS',null,null,v_mon_local);
          v_tip_mov_rubro := 'C';
        elsif v_cod_modalidad = 72 then  -- 72 = VENTA
          v_cod_tip_operacion := 9;
          --v_cod_tip_ope_bcp := null;
          --v_cod_transaccion := 842;
          lp_obt_dat_operacion(v_cod_tip_operacion,v_cod_transaccion,v_tip_ope_bcp);
          v_cod_rubro     := fug_obt_pardinamico('COD_RUB_LIM_POS_CAMBIOS',null,null,v_mon_local);
          v_tip_mov_rubro := 'D';
        end if;

        r_gmovi.cod_usuario     := user;
        r_gmovi.hora            := v_hora;
        r_gmovi.nro_secuencia   := 3; -- FIJO
        r_gmovi.cod_modulo      := v_cod_modulo;
        r_gmovi.cod_modalidad   := v_cod_modalidad;
        r_gmovi.cod_oficina     := v_cod_oficina;
        r_gmovi.nro_cuenta      := null;
        r_gmovi.cod_moneda      := v_mon_local;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_transaccion := v_cod_transaccion;
        r_gmovi.nro_documento   := v_nro_operacion;
        r_gmovi.nro_documento2  := null;
        r_gmovi.monto           := v_tot_mon_local;
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := v_cod_oficina;
        r_gmovi.reversado       := 'N';
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.cod_mod_padre   := v_cod_modulo;
        r_gmovi.cod_mad_padre   := v_cod_modalidad;
        r_gmovi.concepto        := v_concepto;
        r_gmovi.cotizacion      := null;
        r_gmovi.mto_equ_local   := null;
        r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
        r_gmovi.cod_bco_central    := v_tip_ope_bcp;
        r_gmovi.referencia      := v_referencia;
        r_gmovi.cod_persona     := v_cod_persona;
        r_gmovi.cod_rubro       := v_cod_rubro;
        r_gmovi.tip_mov_rubro   := v_tip_mov_rubro;
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

        -- Actualizar la posicion --
        IF v_cod_modalidad = 72 THEN  /* ES UNA VENTA */
           --actualiza la posicion
           UPDATE LC_POSICIONES SET
                  MTO_VTA_NEF_ACT = NVL(MTO_VTA_NEF_ACT,0) + v_monto,
                  MTO_VTA_NEF_LOC = NVL(MTO_VTA_NEF_LOC,0) + v_tot_mon_local
           WHERE COD_TIP_OPE_BCP = v_cod_tip_ope_bcp
             AND COD_MONEDA = v_cod_moneda
             AND COD_OFI_CAMBIO = pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina);
          --inserta posicion si no existe
          IF SQL%NOTFOUND THEN
             INSERT INTO LC_POSICIONES
                 (COD_MONEDA, COD_TIP_OPE_BCP, COD_OFI_CAMBIO,
                  MTO_VTA_NEF_ACT, MTO_VTA_NEF_LOC)
             VALUES
                 (v_cod_moneda, v_cod_tip_ope_bcp,
                  pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina), v_monto,v_tot_mon_local);
          END IF;
        ELSE --es una compra
          --actualiza la posicion
          UPDATE LC_POSICIONES SET
                 MTO_COM_NEF_ACT = NVL(MTO_COM_NEF_ACT,0) + ABS(v_monto),
                 MTO_COM_NEF_LOC = NVL(MTO_COM_NEF_LOC,0) + ABS(v_tot_mon_local)
           WHERE COD_TIP_OPE_BCP = v_cod_tip_ope_bcp
             AND COD_MONEDA = v_cod_moneda
             AND COD_OFI_CAMBIO = pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina);
          --inserta posicion si no existe
          IF SQL%NOTFOUND THEN
             INSERT INTO LC_POSICIONES
                 (COD_MONEDA, COD_TIP_OPE_BCP, COD_OFI_CAMBIO,
                  MTO_COM_NEF_ACT, MTO_COM_NEF_LOC)
             VALUES
                 (v_cod_moneda, v_cod_tip_ope_bcp,
                  pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina), ABS(v_monto), ABS(v_tot_mon_local));
          END IF;
        END IF;
        -- Enviar mail --
        v_hor_inicio := to_char(sysdate, 'hh24:mi:ss');
        v_dir_correo := fug_obt_pardinamico('EMAIL_VER_LIM_POS_CAMBIOS');
        v_asunto     := 'Verificación de Límites de Posición de Cambios';
        if v_dir_correo is not null then
          begin
            prg_env_mail(v_dir_correo_ent, v_dir_correo, v_asunto, v_mensaje);
          exception
            when others then
              -- Si hay error al enviar mail se inserta en la tabla ge_log_mail
               v_mensaje     := v_mensaje||chr(10)||'Error al enviar mail.';
               v_det_error   := substr(sqlerrm, 1, 4000);
               v_hor_fin     := to_char(sysdate, 'hh24:mi:ss');
               INSERT INTO ge_log_mail
                  (fec_envio,cod_persona,dir_correo,mensaje,det_error,nro_cuenta,hor_inicio,hor_fin)
               VALUES
                  (v_fec_actual,v_cod_persona,v_dir_correo,v_mensaje,v_det_error,null,v_hor_inicio,v_hor_fin);
          end;
        end if;
      end if;
    end if;

    --Enviar alerta vía mail
    if nvl(v_env_alerta,'N') = 'S' then
      v_hor_inicio := to_char(sysdate, 'hh24:mi:ss');
      v_dir_correo := fug_obt_pardinamico('EMAIL_VER_LIM_POS_CAMBIOS');
      v_asunto     := 'Verificación de Límites de Posición de Cambios';
      if v_dir_correo is not null then
        begin
          prg_env_mail(v_dir_correo_ent, v_dir_correo, v_asunto, v_mensaje);
        exception
          when others then
            -- Si hay error al enviar mail se inserta en la tabla tm_mails
             v_mensaje     := v_mensaje||chr(10)||' Error al enviar mail. #LPC';
             v_det_error   := substr(sqlerrm, 1, 4000);
             v_cod_persona := LF_OBT_PER_ENTIDAD;
             v_hor_fin     := to_char(sysdate, 'hh24:mi:ss');
             INSERT INTO ge_log_mail
                (fec_envio,cod_persona,dir_correo,mensaje,det_error,nro_cuenta,hor_inicio,hor_fin)
             VALUES
                (v_fec_actual,v_cod_persona,v_dir_correo,v_mensaje,v_det_error,null,v_hor_inicio,v_hor_fin);
        end;
      end if;
    end if;

END;

-- CNFLPCAM-1 -- CN: 11/2015 --
-- Reversion de Boleta inversa por Verificación del Límite de Posición de Cambios --
/* En este procedimiento se realizará la búsqueda de la boleta inversa generada en el cierre Operativo del día hábil anterior
   y de encontrar una realizará la reversión de la misma y se enviará un mail de alerta a un grupo de correos predefinido.
   La búsqueda del movimiento generado el día hábil anterior será realizado por la Referencia igual a "BOL.PROC.NOCTURNO".
   Este proceso será ejecutado en el Inicio Operativo Diario. */
PROCEDURE PR_REV_BOL_INVERSA IS
  v_fec_anterior date := pag_cal.fu_obt_fec_anterior(7);
  v_fec_actual   date := pag_cal.fu_obt_fec_actual(7);
  -- Cursor para obtener la Boleta generada el día hábil anterior Intra día.
  cursor cur_intdia is
    select a.monto, a.cod_moneda, a.cod_modalidad
      from gv_movimientos a
     where a.fecha = v_fec_anterior
       and a.reversado = 'N'
       and a.estado in ('N','J','H')
       and a.cod_mod_padre = 7 -- Módulo -- 7 = CAMBIOS
       and a.cod_mad_padre in (71,72)
       and a.cod_modalidad in (71,72)
       and a.nro_secuencia = 1
       and a.cod_tip_ope_cambio is not null
       and a.referencia like 'BOL.PRO.NOC.INTRADIA'
       and a.cod_moneda <> pag_gen.fu_obt_mon_local;

   -- Cursor para obtener la Boleta generada el día hábil anterior
  cursor cur_datos is
    select a.monto, a.cod_moneda, a.cod_modalidad
      from gv_movimientos a
     where a.fecha = v_fec_anterior
       and a.reversado = 'N'
       and a.estado in ('N','J','H')
       and a.cod_mod_padre = 7 -- Módulo -- 7 = CAMBIOS
       and a.cod_mad_padre in (71,72)
       and a.cod_modalidad in (71,72)
       and a.nro_secuencia = 1
       and a.cod_tip_ope_cambio is not null
       and a.referencia like 'BOL.PROC.NOCTURNO'
       and a.cod_moneda <> pag_gen.fu_obt_mon_local;
  --
   v_hora               ge_movimientos.hora%type := fug_ini_hora(SYSDATE, 'HH24:MI:SS');
   v_monto              ge_movimientos.monto%type;
   v_tot_mon_local      ge_movimientos.monto%type;
   v_cotizacion         ge_movimientos.cotizacion%type;
   v_cod_moneda         ge_movimientos.cod_moneda%type;
   v_mon_local          ge_movimientos.cod_moneda%type;
   v_cod_modulo         ge_movimientos.cod_modulo%type;
   v_cod_modalidad      ge_movimientos.cod_modalidad%type;
   v_cod_persona        ge_movimientos.cod_persona%type;
   v_concepto           ge_movimientos.concepto%type;
   v_referencia         ge_movimientos.referencia%type;
   v_nro_operacion      ge_movimientos.nro_documento%type;
   v_cod_oficina        ge_movimientos.cod_oficina%type;
   v_cod_tra_padre      ge_movimientos.cod_tra_padre%type;
   v_cod_transaccion    ge_movimientos.cod_transaccion%type;
   v_cod_rubro          ge_movimientos.cod_rubro%type;
   v_tip_mov_rubro      ge_movimientos.tip_mov_rubro%type;
   v_nro_cuenta         ge_movimientos.nro_cuenta%type;
   r_gmovi              ge_movimientos%rowtype;
   v_cod_tip_operacion  lc_tip_operaciones.cod_tip_operacion%type;
   v_cod_tip_ope_bcp    lc_tip_operaciones.cod_tip_ope_bcp%type;
   v_tip_ope_bcp        lc_tip_operaciones.cod_tip_ope_bcp%type;
   v_dir_correo_ent     ge_log_mail.dir_correo%type := fug_obt_pardinamico('CAM_MAR_DIR_MAI_NET');--fug_obt_dir_correo; --'bbvanet@bbva.com.py'
   v_dir_correo         ge_par_dinamicos.val_parametro%type;
   v_mensaje            ge_log_mail.mensaje%type;
   v_det_error          ge_log_mail.det_error%type;
   v_hor_inicio         ge_log_mail.hor_inicio%type;
   v_hor_fin            ge_log_mail.hor_fin%type;
   v_asunto             varchar2(500);
   v_redondeo           number;
   v_redondeo_loc       number;
   v_gen_movimiento     varchar2(1) := 'N';

   -- Datos del Tipo de Operacion --
   procedure lp_obt_dat_operacion( p_cod_tip_operacion in lc_tip_operaciones.cod_tip_operacion%type,
                                   p_cod_cod_transaccion in out lc_tip_operaciones.cod_transaccion%type,
                                   p_cod_tip_ope_bcp in out lc_tip_operaciones.cod_tip_ope_bcp%type
                                  ) is
   begin
     select cod_transaccion, cod_tip_ope_bcp
       into p_cod_cod_transaccion, p_cod_tip_ope_bcp
       from lc_tip_operaciones a
      where a.cod_tip_operacion = p_cod_tip_operacion;
   exception
     when others then
       Raise_application_error(-20000, 'Error al obtener datos del Tipo de Operacion '||p_cod_tip_operacion);
   end;
   --
BEGIN
  -- Intra día
  -- Obtener Boleta generada el día hábil anterior --
    v_fec_anterior := pag_cal.fu_obt_fec_anterior(7);
    v_fec_actual := pag_cal.fu_obt_fec_actual(7);
    if cur_intdia%isopen then
      close cur_intdia;
    end if;
    open cur_intdia;
    loop
      fetch cur_intdia
       into v_monto, v_cod_moneda, v_cod_modalidad;
      exit when cur_intdia%notfound;
      --
      if v_cod_modalidad = 71 then    -- 71 = COMPRA
        v_gen_movimiento     := 'S';
        v_cod_modalidad      := 72;     -- 72 = VENTA -- se invierte
        v_cod_tip_operacion  := 31;     -- 31 = VENTA CUENTA CONTABLE
        lp_obt_dat_operacion(v_cod_tip_operacion,v_cod_tra_padre,v_cod_tip_ope_bcp);
        v_cod_rubro     := fug_obt_pardinamico('COD_RUB_LIM_POS_CAMBIOS',null,null,v_cod_moneda);
        v_tip_mov_rubro := 'C';
        v_mensaje := 'Se ha generado la Boleta de Venta de Divisas para reversar la Boleta de Compra de Divisas generada el día anterior por haberse superado el monto límite de sobre venta Intra día establecido.';
      elsif v_cod_modalidad = 72 then    -- 72 = VENTA
        v_gen_movimiento     := 'S';
        v_cod_modalidad      := 71;     -- 71 = COMPRA -- se invierte
        v_cod_tip_operacion  := 17;     -- 17 = COMPRA CUENTA CONTABLE
        --v_cod_tip_ope_bcp    := 'A19';  -- A19 = OTROS
        --v_cod_tra_padre      := 261;
        lp_obt_dat_operacion(v_cod_tip_operacion,v_cod_tra_padre,v_cod_tip_ope_bcp);
        v_cod_rubro     := fug_obt_pardinamico('COD_RUB_LIM_POS_CAMBIOS',null,null,v_cod_moneda);
        v_tip_mov_rubro := 'D';
        v_mensaje := 'Se ha generado la Boleta de Compra de Divisas para reversar la Boleta de Venta de Divisas generada el día anterior por haberse superado el monto límite de sobre compra Intra día establecido.';
      end if;

      -- Generar el movimiento --
      if nvl(v_gen_movimiento,'N') = 'S' then
        v_cotizacion      := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
        v_redondeo        := nvl(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_cod_moneda),2);
        v_hora            := to_char(sysdate,'HH24:MI:SS');
        v_hora            := fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');
        v_cod_oficina     := nvl(fug_obt_pardinamico('COD_OFI_POS_CAMBIOS'),31);
        v_nro_operacion   := fug_obt_lla_pardinamico('NRO_RECIBO', 7, v_cod_modalidad, v_cod_moneda, v_cod_oficina)+1;
        prg_act_par_dinamico('NRO_RECIBO',7, v_cod_modalidad, v_cod_moneda, v_cod_oficina, v_nro_operacion);
        v_mon_local       := pag_gen.fu_obt_mon_local;
        v_redondeo_loc    := nvl(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_mon_local),0);
        v_tot_mon_local   := round(nvl(v_cotizacion,0) * v_monto, v_redondeo_loc);
        v_cod_persona     := LF_OBT_PER_ENTIDAD;
        v_concepto        := 'REV. BOLETAS DE CAMBIOS INTRA DIA - PROCESO NOCTURNO';
        v_referencia      := 'REV.BOL.PRO.NOC.I-D';
        v_cod_modulo      := 7; -- 7 = CAMBIOS
        v_cod_transaccion := v_cod_tra_padre;

        --- genera movimiento ---
        r_gmovi.cod_usuario     := user;
        r_gmovi.hora            := v_hora;
        r_gmovi.nro_secuencia   := 1; -- FIJO 1 para que tome los reportes de cambios
        r_gmovi.cod_modulo      := v_cod_modulo;
        r_gmovi.cod_modalidad   := v_cod_modalidad;
        r_gmovi.cod_oficina     := v_cod_oficina;
        r_gmovi.nro_cuenta      := null;
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_transaccion := v_cod_transaccion;
        r_gmovi.nro_documento   := v_nro_operacion;
        r_gmovi.nro_documento2  := null;
        r_gmovi.monto           := v_monto;
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := v_cod_oficina;
        r_gmovi.reversado       := 'N';
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.cod_mod_padre   := v_cod_modulo;
        r_gmovi.cod_mad_padre   := v_cod_modalidad;
        r_gmovi.concepto        := v_concepto;
        r_gmovi.cotizacion      := v_cotizacion;
        r_gmovi.mto_equ_local   := v_tot_mon_local;
        r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
        r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
        r_gmovi.referencia      := v_referencia;
        r_gmovi.cod_persona     := v_cod_persona;
        r_gmovi.cod_rubro       := v_cod_rubro;
        r_gmovi.tip_mov_rubro   := v_tip_mov_rubro;
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

        v_mensaje := v_mensaje||chr(10)||
                     'Datos de la operación'||chr(10)||
                     'Fecha: '||to_char(v_fec_actual,'dd/mm/yyyy')||chr(10)||
                     'Nro. Operación: '||v_nro_operacion||chr(10)||
                     'Transaccion: '||v_cod_transaccion||chr(10)||
                     'Usuario: '||r_gmovi.cod_usuario||chr(10)||
                     'Hora: '||v_hora||chr(10)||
                     'Concepto: '||v_concepto||chr(10)||
                     'Monto: '||to_char(v_monto,'999G999G999G999D00')||' '||v_cod_moneda;

        --- genera movimiento x persona, para listados ---
        v_cod_transaccion       := 760;
        --asigna cta bolsa
        v_nro_cuenta := fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_oficina);
        r_gmovi.cod_usuario     := user;
        r_gmovi.hora            := v_hora;
        r_gmovi.nro_secuencia   := 2; -- FIJO para que tome los reportes de cambios
        r_gmovi.cod_modulo      := v_cod_modulo;
        r_gmovi.cod_modalidad   := 70; --v_cod_modalidad;
        r_gmovi.cod_oficina     := pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina);
        r_gmovi.nro_cuenta      := v_nro_cuenta;
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_transaccion := v_cod_transaccion;
        r_gmovi.nro_documento   := v_nro_operacion;
        r_gmovi.nro_documento2  := LF_OBT_PER_ENTIDAD;
        r_gmovi.monto           := 0;
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := v_cod_oficina;
        r_gmovi.reversado       := 'N';
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.cod_mod_padre   := v_cod_modulo;
        r_gmovi.cod_mad_padre   := v_cod_modalidad;
        r_gmovi.concepto        := v_concepto;
        r_gmovi.cotizacion      := null;
        r_gmovi.mto_equ_local   := null;
        r_gmovi.cod_tip_ope_cambio := null;
        r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
        r_gmovi.referencia      := v_referencia;
        r_gmovi.cod_persona     := v_cod_persona;
        r_gmovi.cod_rubro       := null;
        r_gmovi.tip_mov_rubro   := null;
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

        -- Generar el Débito o Crédito en Cuenta Contable --
        --v_mon_local := pag_gen.fu_obt_mon_local;
        --v_cod_transaccion       := 842;  -- Modalidad 71=COMPRA CONTABLE CAMBIOS -- Modalidad 72=VENTA CONTABLE CAMBIOS
        if v_cod_modalidad = 71 then  -- 71 = COMPRA
          v_cod_tip_operacion := 4;
          --v_cod_tip_ope_bcp := null;
          --v_cod_transaccion := 741;
          lp_obt_dat_operacion(v_cod_tip_operacion,v_cod_transaccion,v_tip_ope_bcp);
          v_cod_rubro     := fug_obt_pardinamico('COD_RUB_LIM_POS_CAMBIOS',null,null,v_mon_local);
          v_tip_mov_rubro := 'C';
        elsif v_cod_modalidad = 72 then  -- 72 = VENTA
          v_cod_tip_operacion := 9;
          --v_cod_tip_ope_bcp := null;
          --v_cod_transaccion := 842;
          lp_obt_dat_operacion(v_cod_tip_operacion,v_cod_transaccion,v_tip_ope_bcp);
          v_cod_rubro     := fug_obt_pardinamico('COD_RUB_LIM_POS_CAMBIOS',null,null,v_mon_local);
          v_tip_mov_rubro := 'D';
        end if;

        r_gmovi.cod_usuario     := user;
        r_gmovi.hora            := v_hora;
        r_gmovi.nro_secuencia   := 3; -- FIJO
        r_gmovi.cod_modulo      := v_cod_modulo;
        r_gmovi.cod_modalidad   := v_cod_modalidad;
        r_gmovi.cod_oficina     := v_cod_oficina;
        r_gmovi.nro_cuenta      := null;
        r_gmovi.cod_moneda      := v_mon_local;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_transaccion := v_cod_transaccion;
        r_gmovi.nro_documento   := v_nro_operacion;
        r_gmovi.nro_documento2  := null;
        r_gmovi.monto           := v_tot_mon_local;
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := v_cod_oficina;
        r_gmovi.reversado       := 'N';
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.cod_mod_padre   := v_cod_modulo;
        r_gmovi.cod_mad_padre   := v_cod_modalidad;
        r_gmovi.concepto        := v_concepto;
        r_gmovi.cotizacion      := null;
        r_gmovi.mto_equ_local   := null;
        r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
        r_gmovi.cod_bco_central    := v_tip_ope_bcp;
        r_gmovi.referencia      := v_referencia;
        r_gmovi.cod_persona     := v_cod_persona;
        r_gmovi.cod_rubro       := v_cod_rubro;
        r_gmovi.tip_mov_rubro   := v_tip_mov_rubro;
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

        -- Actualizar la posicion --
        IF v_cod_modalidad = 72 THEN  /* ES UNA VENTA */
           --actualiza la posicion
           UPDATE LC_POSICIONES SET
                  MTO_VTA_NEF_ACT = NVL(MTO_VTA_NEF_ACT,0) + v_monto,
                  MTO_VTA_NEF_LOC = NVL(MTO_VTA_NEF_LOC,0) + v_tot_mon_local
           WHERE COD_TIP_OPE_BCP = v_cod_tip_ope_bcp
             AND COD_MONEDA = v_cod_moneda
             AND COD_OFI_CAMBIO = pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina);
          --inserta posicion si no existe
          IF SQL%NOTFOUND THEN
             INSERT INTO LC_POSICIONES
                 (COD_MONEDA, COD_TIP_OPE_BCP, COD_OFI_CAMBIO,
                  MTO_VTA_NEF_ACT, MTO_VTA_NEF_LOC)
             VALUES
                 (v_cod_moneda, v_cod_tip_ope_bcp,
                  pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina), v_monto,v_tot_mon_local);
          END IF;
        ELSE --es una compra
          --actualiza la posicion
          UPDATE LC_POSICIONES SET
                 MTO_COM_NEF_ACT = NVL(MTO_COM_NEF_ACT,0) + ABS(v_monto),
                 MTO_COM_NEF_LOC = NVL(MTO_COM_NEF_LOC,0) + ABS(v_tot_mon_local)
           WHERE COD_TIP_OPE_BCP = v_cod_tip_ope_bcp
             AND COD_MONEDA = v_cod_moneda
             AND COD_OFI_CAMBIO = pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina);
          --inserta posicion si no existe
          IF SQL%NOTFOUND THEN
             INSERT INTO LC_POSICIONES
                 (COD_MONEDA, COD_TIP_OPE_BCP, COD_OFI_CAMBIO,
                  MTO_COM_NEF_ACT, MTO_COM_NEF_LOC)
             VALUES
                 (v_cod_moneda, v_cod_tip_ope_bcp,
                  pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina), ABS(v_monto), ABS(v_tot_mon_local));
          END IF;
        END IF;
        -- Enviar mail --
        v_hor_inicio := to_char(sysdate, 'hh24:mi:ss');
        v_dir_correo := fug_obt_pardinamico('EMAIL_VER_LIM_POS_CAMBIOS');
        v_asunto     := 'Verificación de Límites de Posición de Cambios Intra día';
        if v_dir_correo is not null then
          begin
            prg_env_mail(v_dir_correo_ent, v_dir_correo, v_asunto, v_mensaje);
          exception
            when others then
              -- Si hay error al enviar mail se inserta en la tabla ge_log_mail
               v_mensaje     := v_mensaje||chr(10)||'Error al enviar mail.';
               v_det_error   := substr(sqlerrm, 1, 4000);
               v_hor_fin     := to_char(sysdate, 'hh24:mi:ss');
               INSERT INTO ge_log_mail
                  (fec_envio,cod_persona,dir_correo,mensaje,det_error,nro_cuenta,hor_inicio,hor_fin)
               VALUES
                  (v_fec_actual,v_cod_persona,v_dir_correo,v_mensaje,v_det_error,null,v_hor_inicio,v_hor_fin);
          end;
        end if;
      end if;
      v_gen_movimiento     := 'N';
    end loop;
    if cur_intdia%isopen then
        close cur_intdia;
    end if;
    v_monto          := null;
    v_cod_moneda     := null;
    v_cod_modalidad  := null;
    v_gen_movimiento := 'N';

  -- Fin Intra día
  -- Obtener Boleta generada el día hábil anterior --
    v_fec_anterior := pag_cal.fu_obt_fec_anterior(7);
    v_fec_actual := pag_cal.fu_obt_fec_actual(7);
    if cur_datos%isopen then
      close cur_datos;
    end if;
    open cur_datos;
    loop
      fetch cur_datos
       into v_monto, v_cod_moneda, v_cod_modalidad;
      exit when cur_datos%notfound;
      --
      if v_cod_modalidad = 71 then    -- 71 = COMPRA
        v_gen_movimiento     := 'S';
        v_cod_modalidad      := 72;     -- 72 = VENTA -- se invierte
        v_cod_tip_operacion  := 31;     -- 31 = VENTA CUENTA CONTABLE
        lp_obt_dat_operacion(v_cod_tip_operacion,v_cod_tra_padre,v_cod_tip_ope_bcp);
        v_cod_rubro     := fug_obt_pardinamico('COD_RUB_LIM_POS_CAMBIOS',null,null,v_cod_moneda);
        v_tip_mov_rubro := 'C';
        v_mensaje := 'Se ha generado la Boleta de Venta de Divisas para reversar la Boleta de Compra de Divisas generada el día anterior por haberse superado el monto límite de sobre venta establecido.';
      elsif v_cod_modalidad = 72 then    -- 72 = VENTA
        v_gen_movimiento     := 'S';
        v_cod_modalidad      := 71;     -- 71 = COMPRA -- se invierte
        v_cod_tip_operacion  := 17;     -- 17 = COMPRA CUENTA CONTABLE
        --v_cod_tip_ope_bcp    := 'A19';  -- A19 = OTROS
        --v_cod_tra_padre      := 261;
        lp_obt_dat_operacion(v_cod_tip_operacion,v_cod_tra_padre,v_cod_tip_ope_bcp);
        v_cod_rubro     := fug_obt_pardinamico('COD_RUB_LIM_POS_CAMBIOS',null,null,v_cod_moneda);
        v_tip_mov_rubro := 'D';
        v_mensaje := 'Se ha generado la Boleta de Compra de Divisas para reversar la Boleta de Venta de Divisas generada el día anterior por haberse superado el monto límite de sobre compra establecido.';
      end if;

      -- Generar el movimiento --
      if nvl(v_gen_movimiento,'N') = 'S' then
        v_cotizacion      := pag_gen.fu_obt_cotizacion(v_cod_moneda, v_fec_actual);
        v_redondeo        := nvl(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_cod_moneda),2);
        v_hora            := to_char(sysdate,'HH24:MI:SS');
        v_hora            := fug_obt_hor_disponible(v_fec_actual,v_hora,USER,'N');
        v_cod_oficina     := nvl(fug_obt_pardinamico('COD_OFI_POS_CAMBIOS'),31);
        v_nro_operacion   := fug_obt_lla_pardinamico('NRO_RECIBO', 7, v_cod_modalidad, v_cod_moneda, v_cod_oficina)+1;
        prg_act_par_dinamico('NRO_RECIBO',7, v_cod_modalidad, v_cod_moneda, v_cod_oficina, v_nro_operacion);
        v_mon_local       := pag_gen.fu_obt_mon_local;
        v_redondeo_loc    := nvl(fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',null,null,v_mon_local),0);
        v_tot_mon_local   := round(nvl(v_cotizacion,0) * v_monto, v_redondeo_loc);
        v_cod_persona     := LF_OBT_PER_ENTIDAD;
        v_concepto        := 'REV. BOLETAS DE CAMBIOS - PROCESO NOCTURNO';
        v_referencia      := 'REV.BOL.PROC.NOC';
        v_cod_modulo      := 7; -- 7 = CAMBIOS
        v_cod_transaccion := v_cod_tra_padre;

        --- genera movimiento ---
        r_gmovi.cod_usuario     := user;
        r_gmovi.hora            := v_hora;
        r_gmovi.nro_secuencia   := 1; -- FIJO 1 para que tome los reportes de cambios
        r_gmovi.cod_modulo      := v_cod_modulo;
        r_gmovi.cod_modalidad   := v_cod_modalidad;
        r_gmovi.cod_oficina     := v_cod_oficina;
        r_gmovi.nro_cuenta      := null;
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_transaccion := v_cod_transaccion;
        r_gmovi.nro_documento   := v_nro_operacion;
        r_gmovi.nro_documento2  := null;
        r_gmovi.monto           := v_monto;
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := v_cod_oficina;
        r_gmovi.reversado       := 'N';
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.cod_mod_padre   := v_cod_modulo;
        r_gmovi.cod_mad_padre   := v_cod_modalidad;
        r_gmovi.concepto        := v_concepto;
        r_gmovi.cotizacion      := v_cotizacion;
        r_gmovi.mto_equ_local   := v_tot_mon_local;
        r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
        r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
        r_gmovi.referencia      := v_referencia;
        r_gmovi.cod_persona     := v_cod_persona;
        r_gmovi.cod_rubro       := v_cod_rubro;
        r_gmovi.tip_mov_rubro   := v_tip_mov_rubro;
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

        v_mensaje := v_mensaje||chr(10)||
                     'Datos de la operación'||chr(10)||
                     'Fecha: '||to_char(v_fec_actual,'dd/mm/yyyy')||chr(10)||
                     'Nro. Operación: '||v_nro_operacion||chr(10)||
                     'Transaccion: '||v_cod_transaccion||chr(10)||
                     'Usuario: '||r_gmovi.cod_usuario||chr(10)||
                     'Hora: '||v_hora||chr(10)||
                     'Concepto: '||v_concepto||chr(10)||
                     'Monto: '||to_char(v_monto,'999G999G999G999D00')||' '||v_cod_moneda;

        --- genera movimiento x persona, para listados ---
        v_cod_transaccion       := 760;
        --asigna cta bolsa
        v_nro_cuenta := fug_obt_pardinamico('CTA_CAM_CLI_TEMPORAL',NULL,NULL,NULL,v_cod_oficina);
        r_gmovi.cod_usuario     := user;
        r_gmovi.hora            := v_hora;
        r_gmovi.nro_secuencia   := 2; -- FIJO para que tome los reportes de cambios
        r_gmovi.cod_modulo      := v_cod_modulo;
        r_gmovi.cod_modalidad   := 70; --v_cod_modalidad;
        r_gmovi.cod_oficina     := pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina);
        r_gmovi.nro_cuenta      := v_nro_cuenta;
        r_gmovi.cod_moneda      := v_cod_moneda;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_transaccion := v_cod_transaccion;
        r_gmovi.nro_documento   := v_nro_operacion;
        r_gmovi.nro_documento2  := LF_OBT_PER_ENTIDAD;
        r_gmovi.monto           := 0;
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := v_cod_oficina;
        r_gmovi.reversado       := 'N';
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.cod_mod_padre   := v_cod_modulo;
        r_gmovi.cod_mad_padre   := v_cod_modalidad;
        r_gmovi.concepto        := v_concepto;
        r_gmovi.cotizacion      := null;
        r_gmovi.mto_equ_local   := null;
        r_gmovi.cod_tip_ope_cambio := null;
        r_gmovi.cod_bco_central    := v_cod_tip_ope_bcp;
        r_gmovi.referencia      := v_referencia;
        r_gmovi.cod_persona     := v_cod_persona;
        r_gmovi.cod_rubro       := null;
        r_gmovi.tip_mov_rubro   := null;
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

        -- Generar el Débito o Crédito en Cuenta Contable --
        --v_mon_local := pag_gen.fu_obt_mon_local;
        --v_cod_transaccion       := 842;  -- Modalidad 71=COMPRA CONTABLE CAMBIOS -- Modalidad 72=VENTA CONTABLE CAMBIOS
        if v_cod_modalidad = 71 then  -- 71 = COMPRA
          v_cod_tip_operacion := 4;
          --v_cod_tip_ope_bcp := null;
          --v_cod_transaccion := 741;
          lp_obt_dat_operacion(v_cod_tip_operacion,v_cod_transaccion,v_tip_ope_bcp);
          v_cod_rubro     := fug_obt_pardinamico('COD_RUB_LIM_POS_CAMBIOS',null,null,v_mon_local);
          v_tip_mov_rubro := 'C';
        elsif v_cod_modalidad = 72 then  -- 72 = VENTA
          v_cod_tip_operacion := 9;
          --v_cod_tip_ope_bcp := null;
          --v_cod_transaccion := 842;
          lp_obt_dat_operacion(v_cod_tip_operacion,v_cod_transaccion,v_tip_ope_bcp);
          v_cod_rubro     := fug_obt_pardinamico('COD_RUB_LIM_POS_CAMBIOS',null,null,v_mon_local);
          v_tip_mov_rubro := 'D';
        end if;

        r_gmovi.cod_usuario     := user;
        r_gmovi.hora            := v_hora;
        r_gmovi.nro_secuencia   := 3; -- FIJO
        r_gmovi.cod_modulo      := v_cod_modulo;
        r_gmovi.cod_modalidad   := v_cod_modalidad;
        r_gmovi.cod_oficina     := v_cod_oficina;
        r_gmovi.nro_cuenta      := null;
        r_gmovi.cod_moneda      := v_mon_local;
        r_gmovi.fec_valor       := v_fec_actual;
        r_gmovi.fecha           := v_fec_actual;
        r_gmovi.cod_tra_padre   := v_cod_tra_padre;
        r_gmovi.cod_transaccion := v_cod_transaccion;
        r_gmovi.nro_documento   := v_nro_operacion;
        r_gmovi.nro_documento2  := null;
        r_gmovi.monto           := v_tot_mon_local;
        r_gmovi.estado          := 'N';
        r_gmovi.cod_ofi_origen  := v_cod_oficina;
        r_gmovi.reversado       := 'N';
        r_gmovi.emi_aviso       := 'N';
        r_gmovi.protegido       := 'N';
        r_gmovi.cod_mod_padre   := v_cod_modulo;
        r_gmovi.cod_mad_padre   := v_cod_modalidad;
        r_gmovi.concepto        := v_concepto;
        r_gmovi.cotizacion      := null;
        r_gmovi.mto_equ_local   := null;
        r_gmovi.cod_tip_ope_cambio := v_cod_tip_operacion;
        r_gmovi.cod_bco_central    := v_tip_ope_bcp;
        r_gmovi.referencia      := v_referencia;
        r_gmovi.cod_persona     := v_cod_persona;
        r_gmovi.cod_rubro       := v_cod_rubro;
        r_gmovi.tip_mov_rubro   := v_tip_mov_rubro;
        pag_gen.pr_ins_ge_movimiento(r_gmovi, 'N');

        -- Actualizar la posicion --
        IF v_cod_modalidad = 72 THEN  /* ES UNA VENTA */
           --actualiza la posicion
           UPDATE LC_POSICIONES SET
                  MTO_VTA_NEF_ACT = NVL(MTO_VTA_NEF_ACT,0) + v_monto,
                  MTO_VTA_NEF_LOC = NVL(MTO_VTA_NEF_LOC,0) + v_tot_mon_local
           WHERE COD_TIP_OPE_BCP = v_cod_tip_ope_bcp
             AND COD_MONEDA = v_cod_moneda
             AND COD_OFI_CAMBIO = pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina);
          --inserta posicion si no existe
          IF SQL%NOTFOUND THEN
             INSERT INTO LC_POSICIONES
                 (COD_MONEDA, COD_TIP_OPE_BCP, COD_OFI_CAMBIO,
                  MTO_VTA_NEF_ACT, MTO_VTA_NEF_LOC)
             VALUES
                 (v_cod_moneda, v_cod_tip_ope_bcp,
                  pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina), v_monto,v_tot_mon_local);
          END IF;
        ELSE --es una compra
          --actualiza la posicion
          UPDATE LC_POSICIONES SET
                 MTO_COM_NEF_ACT = NVL(MTO_COM_NEF_ACT,0) + ABS(v_monto),
                 MTO_COM_NEF_LOC = NVL(MTO_COM_NEF_LOC,0) + ABS(v_tot_mon_local)
           WHERE COD_TIP_OPE_BCP = v_cod_tip_ope_bcp
             AND COD_MONEDA = v_cod_moneda
             AND COD_OFI_CAMBIO = pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina);
          --inserta posicion si no existe
          IF SQL%NOTFOUND THEN
             INSERT INTO LC_POSICIONES
                 (COD_MONEDA, COD_TIP_OPE_BCP, COD_OFI_CAMBIO,
                  MTO_COM_NEF_ACT, MTO_COM_NEF_LOC)
             VALUES
                 (v_cod_moneda, v_cod_tip_ope_bcp,
                  pal_cam.FU_OBT_OFI_CAMBIO(v_cod_oficina), ABS(v_monto), ABS(v_tot_mon_local));
          END IF;
        END IF;
        -- Enviar mail --
        v_hor_inicio := to_char(sysdate, 'hh24:mi:ss');
        v_dir_correo := fug_obt_pardinamico('EMAIL_VER_LIM_POS_CAMBIOS');
        v_asunto     := 'Verificación de Límites de Posición de Cambios';
        if v_dir_correo is not null then
          begin
            prg_env_mail(v_dir_correo_ent, v_dir_correo, v_asunto, v_mensaje);
          exception
            when others then
              -- Si hay error al enviar mail se inserta en la tabla ge_log_mail
               v_mensaje     := v_mensaje||chr(10)||'Error al enviar mail.';
               v_det_error   := substr(sqlerrm, 1, 4000);
               v_hor_fin     := to_char(sysdate, 'hh24:mi:ss');
               INSERT INTO ge_log_mail
                  (fec_envio,cod_persona,dir_correo,mensaje,det_error,nro_cuenta,hor_inicio,hor_fin)
               VALUES
                  (v_fec_actual,v_cod_persona,v_dir_correo,v_mensaje,v_det_error,null,v_hor_inicio,v_hor_fin);
          end;
        end if;
      end if;
      v_gen_movimiento     := 'N';
    end loop;
    if cur_datos%isopen then
        close cur_datos;
    end if;
END;
--

end PAL_CIE;
/
