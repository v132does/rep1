CREATE OR REPLACE PROCEDURE IT.PRC_DEB_SAL_MINIMO
 IS
  v_modul        ge_cuentas.cod_modulo%type;
  v_modal        ge_cuentas.cod_modalidad%type;
  v_ofici        ge_cuentas.cod_oficina%type;
  v_moned        ge_cuentas.cod_moneda%type;
  v_cdtrans      ge_movimientos.cod_transaccion%type;
  v_hrmovim      ge_movimientos.hora%type;
  v_encontro     varchar2(1);
  v_traprohi     varchar2(1) := 'N';
  v_autoriza     varchar2(1) := 'N';
  v_pendiente    varchar2(1) := 'N'; 
  v_salprom      cc_cta_corrientes.sal_total%type;
  v_slminpa      cc_cta_corrientes.sal_total%type;
  v_sldispo      cc_cta_corrientes.sal_total%type;
  v_mesact       cc_sal_mensuales.mes%type;
  v_aniact       cc_sal_mensuales.ano%type;
  v_imtrans      cc_cta_corrientes.sal_total%type;
  v_tasaper      varchar2(1);
  v_montcar      ge_movimientos.monto%type;
  v_ini_montcar  ge_movimientos.monto%type;
  v_cmoncar      ge_movimientos.monto%type;
  v_cdtasca      ge_movimientos.cod_tasa%type;
  v_vltasca      ge_movimientos.val_tasa%type;
  v_montimp      cc_cta_corrientes.sal_total%type;
  v_ini_montimp  cc_cta_corrientes.sal_total%type;
  v_cdtasim      ge_movimientos.cod_tasa%type;
  v_vltasim      ge_movimientos.val_tasa%type;
  v_imdebit      cc_cta_corrientes.sal_total%type;
  v_lgpuede      varchar2(1);
  v_esmovim      varchar2(1);
  v_concept      ge_movimientos.concepto%type;
  v_slprome      cc_cta_corrientes.sal_total%type;
  v_cuantos      NUMBER;
  v_slparam      NUMBER;   -- saldo de parametro --
  v_hay_param    varchar2(1);
  v_dias         NUMBER(2,0);
  v_cdusuar      ba_usuarios.cod_usuario%type;
  v_vltasa       ge_tas_fechas.val_tasa%type;
  v_fec_vigencia ge_tas_fechas.fec_vigencia%type;
  v_tipo         ge_tasas.tipo%type;
  v_cdtasas      ah_cta_vistas.cod_tasa%type;
  v_fcdehoy      date;
  v_fcfinal      date;
  v_tpvlpor      varchar2(1);
  v_nrsecue      ge_movimientos.nro_secuencia%type;
  v_nrcuent      cc_cta_corrientes.nro_cuenta%type;
  v_cdmodul      cc_cta_corrientes.cod_modulo%type;
  v_cdmodal      cc_cta_corrientes.cod_modalidad%type;
  v_cdofici      cc_cta_corrientes.cod_oficina%type;
  v_cdmoned      cc_cta_corrientes.cod_moneda%type;
  v_cod_persona  ge_cta_clientes.cod_persona%type;
  v_nro_documento ge_movimientos.nro_documento%type := 0;
  v_cod_mon_local varchar2(4) := pag_gen.FU_OBT_MON_LOCAL;
  v_dia_sobregiros cc_sobregiros_res.can_dias%type;
  v_redondeo      number(4);
  v_es_combinada varchar2(1); 
  r_cte cc_cta_corrientes%rowtype;
  ---
  v_paquete         number := 0;
  v_cod_paq_exnomina ge_paquetes.cod_paquete%type := fug_obt_pardinamico('COD_PAQ_EXNOMINA');
  ---DYDMR-6560     
  v_deb_pendiente   CC_CTA_CORRIENTES_NOC.MTO_DEB_PENDIENTES%TYPE := 0;
  -- DYDMR-9873 - CROMEEXO-1 Mejoras Exoneraciones
  v_val_tas_generica    GE_TAS_FECHAS.VAL_TASA%TYPE;
  v_mto_no_cobrado      ge_movimientos.monto%type;  
CURSOR cte IS
  select *
    from cc_cta_corrientes cc
   where cc.estado not in ('C','P','A','T','D','X')
     and cc.fec_apertura < v_fcdehoy
     --and cc.cod_ente is null   -- No entra Plan Sueldo
	  /*and not exists (select 1
                       from ge_paq_modalidades b, ge_paquetes c
                      where cc.cod_modulo = b.cod_modulo
                        and cc.cod_modalidad = b.cod_modalidad
                        and cc.cod_sub_modalidad = b.cod_sub_modalidad
                        and b.cod_paquete = c.cod_paquete
                        and c.estado = 'A')*/ --AJUSTE CC 1614
for update of estado;
PROCEDURE LP_ACT_AUT (p_modulo      IN     NUMBER,
                      p_modalidad   IN     NUMBER,
                      p_oficina     IN     NUMBER,
                      p_cuenta      IN     CHAR,
                      p_transaccion IN     NUMBER,
                      p_encontro    OUT CHAR);
/* Verifica y devuelve el saldo promedio. */
PROCEDURE LP_VER_SAL_PROMEDIO
         (p_modulo      IN   NUMBER,
          p_modalidad   IN   NUMBER,
          p_oficina     IN   NUMBER,
          p_cuenta      IN   CHAR,
          p_anioactual  IN   NUMBER,
          p_mesactual   IN   NUMBER,
          p_saldo_prom  OUT  NUMBER,
          p_encontro    OUT  CHAR);
/* Actualiza /Inserta Saldos Mensuales */
PROCEDURE LP_ACT_SAL_MENSUAL (P_TOTAL IN NUMBER,
                              P_CDMODUL IN NUMBER,
                              P_CDMODAL IN NUMBER,
                              P_CDOFICI IN NUMBER,
                              P_NRCUENT IN VARCHAR2);
PROCEDURE LP_ACT_AUT (p_modulo      IN     NUMBER,
                      p_modalidad   IN     NUMBER,
                      p_oficina     IN     NUMBER,
                      p_cuenta      IN     CHAR,
                      p_transaccion IN     NUMBER,
                      p_encontro    OUT CHAR) IS
BEGIN
    update ge_autorizaciones set
           cod_usuario     = v_cdusuar,
           fec_utilizacion = v_fcdehoy,
           hor_utilizacion = v_hrmovim
     where cod_modulo      = p_modulo
       and cod_modalidad   = p_modalidad
       and nro_cuenta      = p_cuenta
       and cod_transaccion = p_transaccion
       and eximido         = 'S';
    IF SQL%FOUND THEN
       p_encontro := 'S';
    ELSE
       p_encontro := 'N';
    END IF;
END;
PROCEDURE LP_VER_SAL_PROMEDIO
         (p_modulo      IN   NUMBER,
          p_modalidad   IN   NUMBER,
          p_oficina     IN   NUMBER,
          p_cuenta      IN   CHAR,
          p_anioactual  IN   NUMBER,
          p_mesactual   IN   NUMBER,
          p_saldo_prom  OUT  NUMBER,
          p_encontro    OUT  CHAR) IS
BEGIN
    p_encontro := 'S';
    If v_es_combinada = 'S' then
       SELECT nvl(decode(nvl(s.can_dia_acumulado,0),0,0,(nvl(round(NVL(s.sal_acu_diario,0)/s.can_dia_acumulado,2),0))),0) + nvl(decode(nvl(a.can_dia_acumulado,0),0,0,(nvl(round(NVL(a.sal_acu_diario,0)/a.can_dia_acumulado,2),0))),0)
         INTO p_saldo_prom
         FROM ah_sal_mensuales a, cc_sal_mensuales s, cc_cta_combinadas b
        WHERE s.nro_cuenta = p_cuenta
          and s.ano = p_anioactual 
          and s.mes = p_mesactual 
          and b.nro_cta_cte(+) = s.nro_cuenta 
          and a.nro_cuenta(+)  = b.nro_cta_ahorro 
          and a.ano(+) = p_anioactual
          and a.mes(+) = p_mesactual;
     else          
       SELECT round(NVL(sal_acu_diario,0)/can_dia_acumulado,2)
         INTO p_saldo_prom
         FROM cc_sal_mensuales
        WHERE nro_cuenta    = p_cuenta
          AND ano           = p_anioactual
          AND mes           = p_mesactual;
     End if;     
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      --raise_application_error(-20000,'No encontro en saldos mensuales. Cta : ' || p_cuenta);
      p_saldo_prom := 0;
      p_encontro := 'N';
END;
/* Obtiene el tipo de persona. */
FUNCTION FU_OBT_TIP_PERSONA
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 )
 RETURN VARCHAR2 IS
v_tip_persona varchar2(1); 
BEGIN
     SELECT TIPO
       INTO v_tip_persona
       FROM BA_PERSONAS
      WHERE COD_PERSONA = P_COD_PERSONA;
     return v_tip_persona; 
EXCEPTION
  WHEN OTHERS THEN
   RAISE_APPLICATION_ERROR (-20000,'Error al traer tipo de persona : '||p_cod_persona||' - '||sqlerrm);
END;
/* Obtiene si tiene Linea de Sobregiro. */
FUNCTION FU_VER_LIN_SOBREGIRO
 (P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 )
 RETURN VARCHAR2 IS
v_tiene varchar2(1); 
BEGIN
     SELECT distinct 'S' --DYDMR-7118 - Incidencia SAU - ITGF - Error Cierre 31/07 Linea de Sobregiro
       INTO v_tiene
       FROM CC_LIN_SOBREGIROS
      WHERE NRO_CUENTA = P_NRO_CUENTA
        AND FEC_VENCIMIENTO <= v_fcdehoy ;
    return v_tiene;
EXCEPTION
  WHEN NO_dATA_FOUND THEN
   v_tiene := 'N';
   Return v_tiene;
  WHEN OTHERS THEN
   v_tiene := v_tiene;
   RAISE_APPLICATION_ERROR (-20000,'Error al verificar Linea de Sobregiro : '||p_nro_cuenta||' - '||sqlerrm);
END;
--
PROCEDURE LP_ACT_SAL_MENSUAL (P_TOTAL IN NUMBER,
                              P_CDMODUL IN NUMBER,
                              P_CDMODAL IN NUMBER,
                              P_CDOFICI IN NUMBER,
                              P_NRCUENT IN VARCHAR2)IS
V_DIAS    NUMBER(2,0);
v_minpa   cc_cta_corrientes.sal_total%type;
v_acsaldi cc_cta_corrientes.sal_total%type;
v_salinic cc_cta_corrientes.sal_total%type;
v_ctdiast NUMBER(7);
v_fcproxi DATE;
rv_gcale  GE_CALENDARIOS%ROWTYPE;
v_atransf cc_cta_corrientes.sal_total%type;
v_ctacomb varchar2(1);
BEGIN
  rv_gcale  := pag_cal.fu_obt_reg_cal(4);
  v_fcproxi := rv_gcale.fec_proxima;
  select nvl(cc.sal_total, 0) - nvl(cc.sal_retenido, 0),
         decode(nro_cta_cte,'',0, nvl(cco.sal_minimo, FUG_OBT_SAL_MIN_TRASPASO(nro_cta_cte))), 
         nvl(cc.cta_combinada, 'N')
    into v_salinic, v_atransf, v_ctacomb
    from cc_cta_combinadas cco,
         cc_cta_corrientes cc
   where cco.nro_cta_cte(+) = cc.nro_cuenta
     and cc.cod_modulo    = p_cdmodul
     and cc.cod_modalidad = p_cdmodal
     and cc.cod_oficina   = p_cdofici
     and cc.nro_cuenta    = p_nrcuent;
  If v_ctacomb = 'S' and v_salinic >  v_atransf Then
    v_salinic := v_atransf;
  End If;
  UPDATE cc_sal_mensuales
     SET sal_ini_mes = nvl(v_salinic, 0)
   WHERE cod_modulo    = p_cdmodul
     AND cod_modalidad = p_cdmodal
     AND cod_oficina   = p_cdofici
     AND nro_cuenta    = p_nrcuent
     AND ano           = to_number(to_char(v_fcproxi,'YYYY'))
     AND mes           = to_number(to_char(v_fcproxi,'MM'));
  IF v_fcdehoy + 1 <> v_fcproxi THEN
     V_DIAS := TO_NUMBER(TO_CHAR(v_fcproxi,'DD')) - 1;
     /* Actualiza valores saldo acumulado del mes*/
     UPDATE cc_sal_mensuales
        SET sal_acu_diario = v_dias * nvl(v_salinic, 0)
      WHERE cod_modulo    = p_cdmodul
        AND cod_modalidad = p_cdmodal
        AND cod_oficina   = p_cdofici
        AND nro_cuenta    = p_nrcuent
        AND ano           = to_number(to_char(v_fcproxi,'YYYY'))
        AND mes           = to_number(to_char(v_fcproxi,'MM'));
    -- SALDOS DEUDORES --
    ------------------------------------------------------------
     If nvl(v_salinic, 0) < 0 Then
       UPDATE cc_sal_mensuales
         SET sal_acu_deudor = v_dias * nvl(v_salinic, 0) * -1,
             can_dia_deudor = v_DIAS,
             sal_acu_acreedor = 0,
             can_dia_acreedor = 0
       WHERE cod_modulo    = p_cdmodul
         AND cod_modalidad = p_cdmodal
         AND cod_oficina   = p_cdofici
         AND nro_cuenta    = p_nrcuent
         AND ano           = to_number(to_char(v_fcproxi,'YYYY'))
         AND mes           = to_number(to_char(v_fcproxi,'MM'));
   -- SALDOS ACREEDORES -- menor a cero
    ------------------------------------------------------------
     Else
       UPDATE cc_sal_mensuales
          SET sal_acu_acreedor = v_dias * nvl(v_salinic, 0),
              can_dia_acreedor = v_DIAS,
              sal_acu_deudor = 0,
              can_dia_deudor = 0
        WHERE cod_modulo    = p_cdmodul
          AND cod_modalidad = p_cdmodal
          AND cod_oficina   = p_cdofici
          AND nro_cuenta    = p_nrcuent
          AND ano           = to_number(to_char(v_fcproxi,'YYYY'))
          AND mes           = to_number(to_char(v_fcproxi,'MM'));
     End If;
  END IF;
  IF SQL%NOTFOUND THEN
    raise_application_error(-20000,'No existe reg de mes proximo en CC_SAL_MENSUALES');
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    raise_application_error(-20000,'Error '||p_nrcuent||' '||sqlerrm);
END;
--
/* DYDMR-6560 - 09/06/2017*/
PROCEDURE LP_OBT_DEB_PENDIENTES
 (P_NRO_CUENTA IN CC_CTA_CORRIENTES_NOC.NRO_CUENTA%TYPE,
  P_DEB_PENDIENTE IN OUT CC_CTA_CORRIENTES_NOC.MTO_DEB_PENDIENTES%TYPE) 
 IS
BEGIN
     SELECT NVL(MTO_DEB_PENDIENTES,0)
       INTO P_DEB_PENDIENTE
       FROM CC_CTA_CORRIENTES_NOC
      WHERE NRO_CUENTA = P_NRO_CUENTA;
EXCEPTION
  WHEN OTHERS THEN
       P_DEB_PENDIENTE := 0; 
END;
--***************************
BEGIN
begin pre_ini_aplicacion; pae_cnf.g_cod_modulo := 4; end;
  v_cuantos := 0;
  v_hrmovim := fug_ini_hora(sysdate,'HH24:MI:SS');
  v_nrsecue := 0;
  v_cdusuar := substr(user,1,10);
  v_fcdehoy := pag_cal.fu_obt_fec_actual(4);
  v_aniact  := to_char(v_fcdehoy,'YYYY');
  v_mesact  := to_char(v_fcdehoy,'MM');
  v_hrmovim := fug_obt_hor_disponible(v_fcdehoy,v_hrmovim,user,'N');  -- DYDMR-8168 Abr/2018
  --DELETE fcdbmin;
  ---- ciclo para cada modulo, modal y ofic diferente -----
  IF cte%ISOPEN THEN
     CLOSE cte;
  END IF;
  OPEN cte;
  LOOP
     FETCH cte INTO r_cte;
     EXIT WHEN cte%NOTFOUND;
     v_nrcuent := r_cte.nro_cuenta;
     v_cdmodul := r_cte.cod_modulo;
     v_cdmodal := r_cte.cod_modalidad;
     v_cdofici := r_cte.cod_oficina;
     v_tasaper := nvl(r_cte.tas_personalizada,'N');
     v_es_combinada := r_cte.cta_combinada;
     v_cdtasas := null;
     v_imdebit := 0;
     v_montcar := 0;
     v_montimp := 0;
     v_ini_montcar := 0;
     v_ini_montimp := 0;
     v_cmoncar     := 0;
     --principal de cuenta
     v_cod_persona := fug_obt_cli_principal(r_cte.nro_cuenta);     
     If FU_OBT_TIP_PERSONA(v_cod_persona) = 'F' then -- Para personas fisicas               
        v_cdtrans := 528; -- Trans.Saldo Minimo - Pers.fisicas
     else
        v_cdtrans := 4110; -- Trans.Saldo Minimo - Pers.Juridicas
     end if;       
     if v_nrsecue > 990 then
       v_hrmovim := fug_obt_hor_disponible(v_fcdehoy,v_hrmovim,user,'N');
       v_nrsecue := 0;
     end if;
     /* ve si tiene transacciones prohibidas */
     ------------------------------------------
     v_traprohi := 'N';
     v_pendiente := 'N';
     IF r_cte.tra_prohibida = 'S' THEN
       --verifica transaccion prohibida por la transaccion padre
       v_encontro := PAG_CTA.FU_VER_TRA_PROHIBIDA(r_cte.nro_cuenta, v_cdtrans,
                                                  r_cte.cod_modulo, r_cte.cod_modalidad);
       IF v_encontro = 'S' THEN
          v_traprohi := 'S';
       END IF;
     END IF;
     /* ve si tiene autorizacion */
     ------------------------------------------
     v_autoriza := 'N';
     IF r_cte.aut_pendiente = 'S' THEN
       LP_ACT_AUT (r_cte.cod_modulo, r_cte.cod_modalidad,
                   r_cte.cod_oficina, r_cte.nro_cuenta,
                   v_cdtrans,v_encontro);
       IF v_encontro = 'S' THEN
          v_autoriza := 'S';
       END IF;
     END IF;
     -- ve saldo promedio                   --
     -----------------------------------------
     v_salprom := 0;
     v_encontro := 'N';
     v_dia_sobregiros := 0;
     LP_VER_SAL_PROMEDIO (r_cte.cod_modulo, r_cte.cod_modalidad,
                          r_cte.cod_oficina, r_cte.nro_cuenta,
                          v_aniact       , v_mesact,
                          v_salprom      , v_encontro);
     IF v_encontro = 'S' THEN
         v_slminpa := r_cte.sal_minimo;
         IF v_slminpa IS NULL THEN --no tiene saldo minimo
            --recuperar el saldo minimo del parametro
            v_slparam := FUG_OBT_SAL_MIN_PACTADO(r_cte.cod_moneda, v_cod_persona, r_cte.cod_modulo,
                               r_cte.cod_modalidad, r_cte.cod_oficina,r_cte.cod_sub_modalidad);
            v_slminpa := v_slparam;
         END IF;
         --
         IF v_salprom >= v_slminpa THEN
           GOTO siguiente_registro;
         END IF;
				 /* Verifica los dias de sobregiro del cliente para generarle el cargo. */
				 SELECT nvl(max(can_dias),0)
				   INTO v_dia_sobregiros
					 FROM cc_sobregiros_res
          WHERE nro_cuenta = r_cte.nro_cuenta;
				 
				 IF v_dia_sobregiros >= nvl(fug_obt_pardinamico('DIA_INA_CAR_SOBREGIROS',r_cte.cod_modulo,r_cte.cod_modalidad,r_cte.cod_moneda,r_cte.cod_oficina),9999) then
				    GOTO siguiente_registro;
				 END IF;
         LP_OBT_DEB_PENDIENTES(v_nrcuent, v_deb_pendiente);-- DYDMR-6560
         /* calcular el monto del cargo a debitar */
         v_sldispo := NVL(r_cte.sal_total,0) - NVL(r_cte.sal_retenido,0) - NVL(r_cte.sal_bloqueado,0) - v_deb_pendiente;--DYDMR-6560 - 09/06/2017
         v_cdmoned := r_cte.cod_moneda;
         v_fcfinal := v_fcdehoy;
         --v_cdtrans := 528;  --ya se asigno mas arriba
         v_tpvlpor := ' ';
         --DYDMR-9873 - CROMEEXO-1 Mejoras Exoneraciones - Busca el valor de la tasa Generica
         PAG_GEN.PR_OBT_VAL_TASA(r_cte.cod_modulo,r_cte.cod_modalidad,r_cte.cod_oficina,
                                 null,r_cte.cod_moneda,v_salprom,
                                 v_tasaper, v_cdtasas,v_cdtrans,v_fcfinal,
                                 -- OUT
                                 v_val_tas_generica,v_fec_vigencia,v_tpvlpor,v_tipo);
         --busca valor de tasa para la cuenta                   
         PAG_GEN.PR_OBT_VAL_TASA(r_cte.cod_modulo,r_cte.cod_modalidad,r_cte.cod_oficina,
                                 r_cte.nro_cuenta,r_cte.cod_moneda,v_salprom,
                                 v_tasaper, v_cdtasas,v_cdtrans,v_fcfinal,
                                 -- OUT
                                 v_vltasa,v_fec_vigencia,v_tpvlpor,v_tipo);
         IF v_tpvlpor = 'V' THEN
           If v_traprohi = 'S' or v_autoriza = 'S' Then
              /*
              || PCC-Exoneración y Extorno de Comisiones y Tasas
              */
              prg_ins_exoneracion(v_cdtrans,r_cte.cod_modulo,r_cte.cod_modalidad,r_cte.cod_moneda,
                                  r_cte.NRO_CUENTA,null,v_cdtasca,v_vltasa,v_vltasa,
                                  null,v_vltasa);
              v_montcar := 0;
           Else
              v_montcar := v_vltasa;
           End If;
           v_cmoncar := v_vltasa;
         ELSE
           raise_application_error(-20000,'Cargo de saldo minimo no puede ser porcentual ');
         END IF;
         IF v_cdtasas  IS NULL OR v_vltasa  = 0 THEN
            v_montcar := 0;
            v_cmoncar := 0;
         END IF;
         /* calcular el monto del impuesto sobre el cargo a debitar */
         -------------------------------------------------------------
         v_vltasca := v_vltasa;
         v_cdtasca := v_cdtasas;
         v_imtrans := v_montcar;
         v_montimp := 0;
         --- Agregado para que calcule el impuesto ---
         /* ve si tiene transacciones prohibidas */
         ------------------------------------------
         --solo si no tiene transaccion padre prohibida y si no tiene linea de sobregiro vigente
         --y si el cargo es distinto de cero
         If  nvl(v_traprohi,'N') <> 'S' 
         and FU_VER_LIN_SOBREGIRO(r_cte.nro_cuenta) = 'N'
         and v_montcar <> 0 then
            v_traprohi := 'N';
            IF r_cte.tra_prohibida = 'S' THEN
              v_encontro := PAG_CTA.FU_VER_TRA_PROHIBIDA(r_cte.nro_cuenta, 517,
                                                         r_cte.cod_modulo, r_cte.cod_modalidad);
              IF v_encontro = 'S' THEN
                v_traprohi := 'S';
              END IF;
            END IF;
            v_nrcuent := r_cte.nro_cuenta;
            v_cdmodul := r_cte.cod_modulo;
            v_cdmodal := r_cte.cod_modalidad;
            v_cdofici := r_cte.cod_oficina;
            v_tasaper := nvl(r_cte.tas_personalizada,'N');
            v_cdtasas := null;
            v_cdmoned := r_cte.cod_moneda;
            v_fcfinal := v_fcdehoy;
            v_tpvlpor := ' ';
            PAG_GEN.PR_OBT_VAL_TASA(r_cte.cod_modulo,r_cte.cod_modalidad,r_cte.cod_oficina,
                                    r_cte.nro_cuenta,r_cte.cod_moneda,0,
                                    v_tasaper, v_cdtasas,517,v_fcfinal,
                                   -- OUT
                                    v_vltasa,v_fec_vigencia,v_tpvlpor,v_tipo);
            v_vltasim  := v_vltasa;
            v_cdtasim  := v_cdtasas;
            v_redondeo := fug_obt_pardinamico('VAL_RED_MON_EXTRANJERA',r_cte.cod_modulo,r_cte.cod_modalidad,r_cte.cod_moneda);
            IF v_tpvlpor = 'V' THEN
              raise_application_error(-20000,'IVA de Cargo de saldo minimo debe ser porcentual');
            ELSE
                --If v_traprohi = 'N' Then
                  If v_cmoncar > 0 Then
                     v_montimp := Round(nvl(v_cmoncar,0) *
                                        nvl(v_vltasim,0) / 100, v_redondeo);
                     
                     --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                     v_montimp := pag_gen.FU_OBT_VAL_FINAL(v_montimp);
                     
                  End If;
                  /*
                  || PCC-Exoneración y Extorno de Comisiones y Tasas
                  */
                  If v_traprohi = 'S' Then
                     prg_ins_exoneracion(v_cdtrans,r_cte.cod_modulo,r_cte.cod_modalidad,
                                         r_cte.cod_moneda,r_cte.NRO_CUENTA,null,
                                         v_cdtasca,v_montimp,v_montimp,
                                         null,v_montimp);
                     v_montimp := 0;
                  End If;
                --End If;
            END IF;
            --  /* calcular la diferencia para saber si el saldo disponible
            --     alcanza para el debito del cargo e impuesto.               */
            v_imdebit := v_montcar + v_montimp;
            -- guardo los importes originales
            v_ini_montcar := v_montcar;
            v_ini_montimp := v_montimp;
            v_lgpuede := 'S';
            IF v_sldispo - v_imdebit < 0 THEN
              --v_lgpuede := 'N';
              v_lgpuede := 'S';
              v_esmovim := 'N';
              -- if r_cte.estado = 'I' then  -- cuentas inactivas
              -- ya no importa si esta inactiva. Siempre se cobra solo lo que tiene, pedido
              -- de Yanagida 28/12/06
              if v_sldispo = 0 then    -- no esta sobregirado, no se le sobregira pero se deja pendiente
                 v_pendiente := 'S';
                 v_lgpuede := 'N';
              elsif v_sldispo <> 0 then    --si tiene saldo o si esta sobregirado se le cobra igual
                 if  v_sldispo > 0 then
                   -- recalculo para cobrarle hasta el monto disponible
                   v_montcar := round(v_sldispo * v_montcar / v_imdebit, v_redondeo);
                   v_montimp := v_sldispo - v_montcar;
                   v_imdebit := nvl(v_montcar,0) + nvl(v_montimp, 0);    
                   v_lgpuede := 'S';                
                   v_pendiente := 'S';
                 else
                   v_lgpuede := 'S';                
                   v_pendiente := 'N';                     
                 end if;  
              end if;
              -- end if;
            END IF;
            IF v_lgpuede = 'S' THEN
              v_esmovim := 'N';
            ELSE
              If v_montcar > 0 Then
                 v_concept := 'DEBITO POR SALDO MINIMO '||to_char(v_fcdehoy,'dd/mm/yyyy');
                 v_esmovim := 'E';
                 v_cuantos := v_cuantos + 1;
              End If;
            END IF;
            /*
            || PCC-Exoneración y Extorno de Comisiones y Tasas
            */
            v_paquete := 0;
            begin
               SELECT count(1)
                 INTO v_paquete
                 FROM ge_paq_modalidades b, ge_paquetes c
                WHERE r_cte.cod_modulo = b.cod_modulo
                  AND r_cte.cod_modalidad = b.cod_modalidad
                  AND r_cte.cod_sub_modalidad = b.cod_sub_modalidad
                  AND b.cod_paquete = c.cod_paquete
                  AND (c.estado = 'A' or (c.estado = 'I' and c.cod_paquete = v_cod_paq_exnomina));
            exception
               when no_data_found then
                  v_paquete := 0;
               when too_many_rows then
                  v_paquete := 1;
               when others then
                  raise_application_error(-20000,'AL Obt.Paquete:'||sqlerrm);
            end;
            if r_cte.cod_ente IS NOT NULL or -- es PLAN SUELDOS
               nvl(v_paquete, 0) <> 0 or -- es paquete
               nvl(v_val_tas_generica,0) <> nvl(v_vltasca,0) then -- tiene exoneracion
               
               --DYDMR-9873 - CROMEEXO-1 - si tiene paquete o es de un ente exonera 100%
               if r_cte.cod_ente IS NOT NULL or -- es PLAN SUELDOS
                  nvl(v_paquete, 0) <> 0 then -- es paquete
                  v_lgpuede   := 'N';
                  v_pendiente := 'N';
                  --DYDMR-9873 - CROMEEXO-1 registra exoneracion 100%
                  prg_ins_exoneracion( v_cdtrans,r_cte.cod_modulo,r_cte.cod_modalidad,r_cte.cod_moneda,
                                   r_cte.NRO_CUENTA,null,v_cdtasca,v_val_tas_generica,v_val_tas_generica,
                                   null,v_val_tas_generica);
               else
                 --registra exoneracion por tasa personalizada
                 v_mto_no_cobrado := nvl(v_val_tas_generica,0) - nvl(v_vltasca,0);
                 prg_ins_exoneracion( v_cdtrans,r_cte.cod_modulo,r_cte.cod_modalidad,r_cte.cod_moneda,
                                 r_cte.NRO_CUENTA,null,v_cdtasca,v_vltasca,v_val_tas_generica,
                                 null,v_mto_no_cobrado);
               end if;
            end if;
            ---
            If v_lgpuede = 'S' then
              if v_montcar > 0 or v_montimp > 0 then
                 --generar movimientos
                 v_nro_documento := v_nro_documento + 1;
              end if;
              IF v_montcar > 0 THEN
             -- movimiento de debito
             -----------------------
               v_nrsecue := v_nrsecue + 1;
               insert into ge_movimientos
                (cod_usuario, hora, nro_secuencia,
                 cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
                 cod_moneda, cod_tra_padre, cod_transaccion, fecha,
                 fec_valor, monto, estado, cod_ofi_origen,
                 cod_tasa, val_tasa, cod_mod_padre, cod_mad_padre,
                 reversado, protegido, nro_documento, concepto)
               VALUES
                (v_CDUSUAR, v_HRMOVIM, v_NRSECUE,
                 r_cte.cod_modulo, r_cte.cod_modalidad, r_cte.cod_oficina,
                 r_cte.nro_cuenta, r_cte.cod_moneda, v_cdtrans,v_cdtrans,v_fcdehoy,
                 v_fcdehoy, v_montcar, v_esmovim,r_cte.cod_oficina,
                 v_cdtasca, v_vltasca,r_cte.cod_modulo, r_cte.cod_modalidad,'N','N', v_nro_documento, v_concept);
              END IF;
              IF v_montimp > 0 THEN
             -- movimiento de debito
             -----------------------
               v_nrsecue := v_nrsecue + 1;
               insert into ge_movimientos
                 (cod_usuario, hora, nro_secuencia,
                 cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
                 cod_moneda, cod_tra_padre, cod_transaccion, fecha,
                 fec_valor, monto, estado, cod_ofi_origen,
                 cod_tasa, val_tasa, cod_mod_padre, cod_mad_padre,
                 reversado, protegido, nro_documento, concepto)
               values
                (v_cdusuar, v_hrmovim, v_nrsecue,
                 r_cte.cod_modulo, r_cte.cod_modalidad, r_cte.cod_oficina,
                 r_cte.nro_cuenta, r_cte.cod_moneda, 517,517,v_fcdehoy,
                 v_fcdehoy, v_montimp, 'N',r_cte.cod_oficina,
                 v_cdtasim, v_vltasim,4, 41,'N','N', v_nro_documento, v_concept);
              End if;--mto imp
            end if;  
            /*
            --- Ver si se deja pendiente total o parcialmente
            */
            If v_pendiente = 'S' then
              --Ver si queda pendiente solo una porcion o totalmente
              if v_montcar <> v_ini_montcar then   --queda pendiente la porcion que no se pudo debitar
                 v_montcar := v_ini_montcar-v_montcar;
                 if  v_ini_montimp <> 0 then
                    v_montimp := Round(nvl(v_montcar,0) *
                                        nvl(v_vltasim,0) / 100, v_redondeo);
                     --verificar si el monto a cobrar está limitado x el mínimo y máximo de la tasa
                    v_montimp := pag_gen.FU_OBT_VAL_FINAL(v_montimp);
                 end if;
              end if;      
              --Generar movimiento Pendiente
              if v_montcar > 0 or v_montimp > 0 then
                 --generar movimientos
                 v_nro_documento := v_nro_documento + 1;
              end if;
              IF v_montcar > 0 THEN
                -- movimiento de debito
                -----------------------
                -- RI : 02/02/2010 : Si la cuenta esta inactiva y no tiene saldo no se graba mov.pendiente
                If  v_sldispo = 0 and R_CTE.estado = 'I' then
                  null;
                else
                 insert into ge_mov_pendientes
                  (cod_usuario, hora, 
                   cod_modulo, cod_modalidad, cod_oficina, nro_cuenta,
                   cod_moneda, cod_tra_padre, cod_transaccion, fecha,
                   monto, estado, cod_ofi_origen,
                   cod_tasa, val_tasa, cod_mod_padre, cod_mad_padre,
                   nro_documento, concepto, saldo)
                 VALUES
                  (v_CDUSUAR, v_HRMOVIM, 
                   r_cte.cod_modulo, r_cte.cod_modalidad, r_cte.cod_oficina,
                   r_cte.nro_cuenta, r_cte.cod_moneda, v_cdtrans,v_cdtrans,v_fcdehoy,
                   nvl(v_montcar,0)+nvl(v_montimp,0), 'I',r_cte.cod_oficina,
                   v_cdtasca, v_vltasca,r_cte.cod_modulo, r_cte.cod_modalidad, v_nro_documento, v_concept,
                   nvl(v_montcar,0)+nvl(v_montimp,0) );
                END IF;   
              END IF;
            End if;  -- Fin v_pendiente = 'S'
            
            IF v_lgpuede = 'S' then
             -- actualizar el maestro de cuentas corrientes
              update cc_cta_corrientes
                 set sal_total = sal_total - v_imdebit ,
                     fec_ult_movimiento = v_fcdehoy,
                     hor_ult_movimiento = v_hrmovim
               where current of cte;
             -- actualizar el acumulado de saldos mensuales
              LP_ACT_SAL_MENSUAL(v_imdebit, r_cte.cod_modulo,
                                 r_cte.cod_modalidad,r_cte.cod_oficina, r_cte.nro_cuenta);
            end if;
       end if; --si no tiene tra padre prohibida
     End if;--si encontro = s
     <<siguiente_registro>>
     NULL;
  END LOOP;
  IF cte%ISOPEN THEN
    CLOSE cte;
  END IF;
EXCEPTION
  when no_data_found then
    raise_application_error(-20000,'No existe datos en el archivo');
end;
/

