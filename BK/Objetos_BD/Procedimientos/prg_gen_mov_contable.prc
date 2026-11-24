CREATE OR REPLACE PROCEDURE IT.PRG_GEN_MOV_CONTABLE
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_NRO_CUENTA IN GE_CUENTAS.NRO_CUENTA%TYPE
 ,RP_GMOVI IN GE_MOVIMIENTOS%ROWTYPE
 ,P_NRO_SECUENCIA IN OUT GE_MOVIMIENTOS.NRO_SECUENCIA%TYPE
 )
 IS

/* Obtener tipo de asiento para la transacción. */
PROCEDURE LP_OBT_ASI_TRAN
 (P_COD_MODULO IN GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_TIP_ASIENTO IN OUT GE_TRANSACCIONES.COD_TIP_ASIENTO%TYPE
 ,P_COD_PRO_CONTABLE IN OUT GE_MODALIDADES.COD_PRO_CONTABLE%TYPE
 );
/* Obtener datos contables del cliente. */
PROCEDURE LP_OBT_DAT_CON_CLI
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_COD_SEC_CONTABLE IN OUT GE_CLIENTES.COD_SEC_CONTABLE%TYPE
 ,P_RESIDENTE IN OUT GE_CLIENTES.RESIDENTE%TYPE
 ,P_COD_TIP_DEUDOR IN OUT GE_CLIENTES.COD_TIP_DEUDOR%TYPE
 ,P_CAT_AUTOMATICA IN OUT GE_CLIENTES.CAT_AUTOMATICA%TYPE
 );
v_cod_moneda        ba_monedas.cod_moneda%type;
   v_ctdias            number(06);
   v_cod_plazo         ge_plz_contables.cod_plazo%type;
   v_cod_tip_asiento   ge_tip_asientos.cod_tip_asiento%type;
   V_EST_CUENTA        GE_TIP_ASIENTOS.EST_CUENTA%TYPE;
   V_TIP_CUENTA        GE_TIP_ASIENTOS.TIP_CUENTA%TYPE;
   V_TIP_INTERES       GE_TIP_ASIENTOS.TIP_INTERES%TYPE;
   V_TIP_RENOVACION    GE_TIP_ASIENTOS.TIP_RENOVACION%TYPE;
   V_CAT_AUTOMATICA    GE_TIP_ASIENTOS.CAT_AUTOMATICA%TYPE;
   v_cod_pro_contable  ge_modalidades.cod_pro_contable%type;
   v_cod_sec_contable  ge_clientes.cod_sec_contable%type;
   v_residente         ge_clientes.residente%type;
   v_cod_tip_deudor    ge_clientes.cod_tip_deudor%type;
   CURSOR c_ge_tip_asientos IS
   SELECT IND_PLAZO, IND_DEUDOR, TIP_MOVIMIENTO, COD_RUBRO, IND_PRODUCTO
     FROM GE_TIP_ASIENTOS
    WHERE COD_TIP_ASIENTO  = v_cod_tip_asiento
      AND COD_MONEDA       = v_cod_moneda
      AND COD_SEC_CONTABLE = v_cod_sec_contable
      AND (IND_RESIDENTE   = v_residente      OR IND_RESIDENTE = 'X')
      AND (est_cuenta      = v_est_cuenta     or nvl(est_cuenta,'X') = 'X')
      AND (tip_cuenta      = v_tip_cuenta     or nvl(tip_cuenta,'X') = 'X')
      AND (tip_interes     = v_tip_interes    or nvl(tip_interes,'X') = 'X')
      AND (tip_renovacion  = v_tip_renovacion or nvl(tip_renovacion,'X') = 'X')
      AND (cat_automatica  = v_cat_automatica or nvl(cat_automatica,-1) = -1);
   v_contador        NUMBER(06) := 0;
   v_cod_rubro       cb_rubros.cod_rubro%type;
   r_gmovi           ge_movimientos%rowtype;
   v_nro_secuencia   ge_movimientos.nro_secuencia%type;
v_cod_sec_rubro ge_con_transacciones.cod_sec_rubro%type;
/* Obtener tipo de asiento para la transacción. */
PROCEDURE LP_OBT_ASI_TRAN
 (P_COD_MODULO IN GE_TRANSACCIONES.COD_MODULO%TYPE
 ,P_COD_MODALIDAD IN GE_TRANSACCIONES.COD_MODALIDAD%TYPE
 ,P_COD_TRANSACCION IN GE_TRANSACCIONES.COD_TRANSACCION%TYPE
 ,P_COD_TIP_ASIENTO IN OUT GE_TRANSACCIONES.COD_TIP_ASIENTO%TYPE
 ,P_COD_PRO_CONTABLE IN OUT GE_MODALIDADES.COD_PRO_CONTABLE%TYPE
 )
 IS
BEGIN
   SELECT G.COD_TIP_ASIENTO, M.COD_PRO_CONTABLE
     INTO p_cod_tip_asiento, p_cod_pro_contable
     FROM GE_MODALIDADES M, GE_TRANSACCIONES G
    WHERE m.cod_modulo = g.cod_modulo
      AND m.cod_modalidad = g.cod_modalidad
      AND g.COD_MODULO = p_cod_modulo
      AND g.COD_MODALIDAD = p_cod_modalidad
      AND g.COD_TRANSACCION = p_cod_transaccion;
   IF v_cod_tip_asiento IS NULL THEN
      v_cod_tip_asiento := NULL;
   END IF;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      p_cod_tip_asiento := NULL;
      P_COD_PRO_CONTABLE := NULL;
   WHEN OTHERS THEN
      raise_application_error(-20000, 'BUSCA_TRANS: '||SQLERRM);
END;
/* Obtener datos contables del cliente. */
PROCEDURE LP_OBT_DAT_CON_CLI
 (P_COD_PERSONA IN BA_PERSONAS.COD_PERSONA%TYPE
 ,P_COD_SEC_CONTABLE IN OUT GE_CLIENTES.COD_SEC_CONTABLE%TYPE
 ,P_RESIDENTE IN OUT GE_CLIENTES.RESIDENTE%TYPE
 ,P_COD_TIP_DEUDOR IN OUT GE_CLIENTES.COD_TIP_DEUDOR%TYPE
 ,P_CAT_AUTOMATICA IN OUT GE_CLIENTES.CAT_AUTOMATICA%TYPE
 )
 IS
BEGIN
   SELECT COD_SEC_CONTABLE,RESIDENTE,COD_TIP_DEUDOR,
          fup_obt_categoria(cat_automatica,cat_subjetiva)
     INTO p_cod_sec_contable,p_residente,p_cod_tip_deudor,
          p_cat_automatica
     FROM GE_CLIENTES
    WHERE COD_PERSONA = p_cod_persona;
EXCEPTION
   WHEN NO_DATA_FOUND THEN
      raise_application_error(-20000, 'Cliente '||p_cod_persona||' no registrado');
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Obt.Dat.Cliente '||SQLERRM);
END;

BEGIN
   v_nro_secuencia := null;
   --- Recuperar datos contable de la persona
   LP_OBT_DAT_CON_CLI(p_cod_persona, v_cod_sec_contable, v_residente,
                      v_cod_tip_deudor, v_cat_automatica);
   --- Recuperar datos contables de la cuenta
   BEGIN
      SELECT PRE.COD_MONEDA, PRE.FEC_VENCIMIENTO - PRE.FEC_INICIO,
             tipo, tip_interes, nvl(tip_renovacion,'A'), decode(estado,'N',est_batch,estado) estado, --para los que cancela en el día,debe ir el estado anterior
             FUP_OBT_SEC_RUBRO(pre.cod_sec_credito)
        INTO v_cod_moneda, v_ctdias,
             v_tip_cuenta, v_tip_interes, v_tip_renovacion, v_est_cuenta,
             v_cod_sec_rubro
        FROM PR_CTA_PRESTAMOS PRE
       WHERE PRE.NRO_CUENTA = p_nro_cuenta;
   EXCEPTION
      when no_data_found then
         raise_application_error(-20000,'Cuenta '||p_nro_cuenta||' no registrada');
   END;
   v_cod_plazo := fug_obt_plz_contable(v_ctdias);
   --- Obtener tipo de asiento
   lp_obt_asi_tran(rp_gmovi.cod_modulo,rp_gmovi.cod_modalidad,rp_gmovi.cod_transaccion,
                   v_cod_tip_asiento, v_cod_pro_contable);
   IF NVL(v_cod_tip_asiento,0) > 0 THEN
      --- Inicializar registro de movimientos con lo del parametro
      r_gmovi         := rp_gmovi;
      v_nro_secuencia := nvl(rp_gmovi.nro_secuencia,0) + 1;
      FOR FGT IN c_ge_tip_asientos LOOP
         v_contador  := NVL(v_contador,0) + 1;
         v_cod_rubro := FGT.COD_RUBRO;
         IF FGT.IND_DEUDOR = 'S' THEN
            v_cod_rubro := SUBSTR(v_cod_rubro,1,8)||
                           LTRIM(TO_CHAR(v_cod_tip_deudor,'00'))||
                           SUBSTR(v_cod_rubro,11,5);
         END IF;
         IF FGT.IND_PLAZO = 'S' THEN
            v_cod_rubro:= SUBSTR(v_cod_rubro,1,2)||
                          LTRIM(TO_CHAR(v_cod_plazo))||
                          SUBSTR(v_cod_rubro,4,12);
         END IF;
         IF FGT.IND_PRODUCTO = 'S' THEN
            v_cod_rubro := SUBSTR(v_cod_rubro,1,10)||
                          LTRIM(TO_CHAR(v_cod_pro_contable,'000'))||
                          SUBSTR(v_cod_rubro,14,2);
         END IF;
         --Reemplaza el código del sector de crédito
         IF substr(FGT.cod_rubro,11,3)  = 'SEC' THEN
            v_cod_rubro := SUBSTR(v_cod_rubro,1,10)||
                          LTRIM(TO_CHAR(v_cod_sec_rubro,'000'))||
                          SUBSTR(FGT.COD_RUBRO,14,2);
         END IF;         
         v_nro_secuencia         := v_nro_secuencia + 1;
         r_gmovi.nro_secuencia   := v_nro_secuencia;
         r_gmovi.cod_rubro       := v_cod_rubro;
         r_gmovi.tip_mov_rubro   := fgt.tip_movimiento;
         r_gmovi.cod_transaccion := null; --- Para que no genere consolidado
         pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
      END LOOP;
      IF v_contador = 0 THEN
         raise_application_error(-20000, 'No existe asiento.:'||to_char(v_cod_tip_asiento)||
          ' Res.:'||v_residente||' Sec.'||v_cod_sec_contable||' Modalidad: '||
          to_char(r_gmovi.cod_modalidad)||' Transaccion: '||r_gmovi.cod_transaccion||' ');
      END IF;
   END IF;
   p_nro_secuencia := nvl(v_nro_secuencia,rp_gmovi.nro_secuencia);
EXCEPTION
   WHEN OTHERS THEN
      if sqlcode <= -20000 then
         raise;
      else
         raise_application_error(-20000, 'Obt.Asi.Asociado '||to_char(v_cod_tip_asiento)||
                               ' Modalidad: '||to_char(r_gmovi.cod_modalidad)||'Transaccion: '||r_gmovi.cod_transaccion||' '||sqlerrm);
      end if;
END;
/

