CREATE OR REPLACE PROCEDURE IT.PRL_GEN_ASI_UTILIDAD
 IS

/* Obtiene la cuenta contable para generar asientos. */
PROCEDURE LP_OBT_CTA_CONTABLE
 (P_COD_TIP_ASIENTO IN GE_TIP_ASIENTOS.COD_TIP_ASIENTO%TYPE
 ,P_NRO_LINEA IN GE_TIP_ASIENTOS.NRO_LINEA%TYPE
 ,P_COD_MONEDA IN GE_TIP_ASIENTOS.COD_MONEDA%TYPE
 ,P_COD_RUBRO IN OUT GE_TIP_ASIENTOS.COD_RUBRO%TYPE
 ,P_COD_MON_RUBRO IN OUT GE_TIP_ASIENTOS.COD_MONEDA%TYPE
 );
--- OBS: Ultimo Proceso del cierre de Cambios
--- Genera asientos de utilidad de cambios
   v_fec_actual     ge_calendarios.fec_actual%type;
   v_cod_mon_local  ba_monedas.cod_moneda%type;
   ------------------------------------------------------------------
   -- Cursor de los registros del LC_SAL_DIARIOS.
   ------------------------------------------------------------------
   CURSOR MONEDA IS
   SELECT MTO_UTI_EFE_REAL, MTO_UTI_EFE_NETA, MTO_UTI_NEF_REAL, MTO_UTI_NEF_NETA,
          COD_OFICINA, COD_MONEDA
     FROM LC_SAL_DIARIOS
    WHERE COD_MONEDA <> v_cod_mon_local;
   ------------------------------------------------------------------
   W_CDMONED  LC_SAL_DIARIOS.COD_MONEDA%TYPE;
   W_CTCOREF  cb_rubros.cod_rubro%type;
   W_CDMNREF  cb_rubros.cod_moneda%type;
   W_UTILREF  LC_SAL_DIARIOS.MTO_UTI_EFE_REAL%TYPE;
   W_CTCONEF  cb_rubros.cod_rubro%type;
   W_CDMNNEF  cb_rubros.cod_moneda%type;
   W_UTILNEF  LC_SAL_DIARIOS.MTO_UTI_EFE_NETA%TYPE;
   W_CTCORNE  cb_rubros.cod_rubro%type;
   W_CDMNRNE  cb_rubros.cod_moneda%type;
   W_UTILRNE  LC_SAL_DIARIOS.MTO_UTI_NEF_REAL%TYPE;
   W_CTCONNE  cb_rubros.cod_rubro%type;
   W_CDMNNNE  cb_rubros.cod_moneda%type;
   W_UTILNNE  LC_SAL_DIARIOS.MTO_UTI_NEF_REAL%TYPE;
   W_CDOFICI  LC_SAL_DIARIOS.COD_OFICINA%TYPE;
   W_IMTRANS  NUMBER;
   W_IMPEQGS  NUMBER;
   W_DEBCRE   VARCHAR2(01);
   ------------------------------------------------------------------
   v_hora           ge_movimientos.hora%type;
   v_nro_secuencia  ge_movimientos.nro_secuencia%type;
   r_gmovi          ge_movimientos%rowtype;

/* Obtiene la cuenta contable para generar asientos. */
PROCEDURE LP_OBT_CTA_CONTABLE
 (P_COD_TIP_ASIENTO IN GE_TIP_ASIENTOS.COD_TIP_ASIENTO%TYPE
 ,P_NRO_LINEA IN GE_TIP_ASIENTOS.NRO_LINEA%TYPE
 ,P_COD_MONEDA IN GE_TIP_ASIENTOS.COD_MONEDA%TYPE
 ,P_COD_RUBRO IN OUT GE_TIP_ASIENTOS.COD_RUBRO%TYPE
 ,P_COD_MON_RUBRO IN OUT GE_TIP_ASIENTOS.COD_MONEDA%TYPE
 )
 IS
BEGIN
   select GE_TIP_ASIENTOS.cod_rubro, 
         DECODE(SUBSTR(GE_TIP_ASIENTOS.COD_RUBRO,14,2),'98','GS','99','GS',NVL(cb_rubros.cod_moneda,ge_tip_asientos.cod_moneda)) cod_moneda
/*   select cb_rubros.cod_rubro, cb_rubros.cod_moneda */
     into p_cod_rubro, p_cod_mon_rubro 
     from cb_rubros, ge_tip_asientos
    where ge_tip_asientos.cod_tip_asiento = p_cod_tip_asiento
      and cb_rubros.cod_rubro(+) = ge_tip_asientos.cod_rubro
      and ge_tip_asientos.nro_linea = p_nro_linea
      and ge_tip_asientos.cod_moneda = p_cod_moneda
      and (ge_tip_asientos.cod_sec_contable = 'X' or ge_tip_asientos.cod_sec_contable is null);
exception
   when no_data_found then
      p_cod_rubro     := null;
      p_cod_mon_rubro := null;
   when too_many_rows then
      raise_application_error(-20000,
      'Asientos duplicados p/As '||p_cod_tip_asiento||
      ' Linea '||p_nro_linea||
      ' Moneda '||p_cod_moneda);
END;
BEGIN
   v_cod_mon_local := pag_gen.fu_obt_mon_local;
   v_fec_actual    := pag_cal.fu_obt_fec_actual(7);
   v_hora                 := fug_ini_hora(SYSDATE,'HH24:MI:SS');
   v_nro_secuencia        := 0;

   IF MONEDA%ISOPEN THEN
      CLOSE MONEDA;
   END IF;
   OPEN MONEDA;
   LOOP
      FETCH MONEDA INTO W_UTILREF, W_UTILNEF, W_UTILRNE, W_UTILNNE,
                        W_CDOFICI, W_CDMONED;
      EXIT WHEN MONEDA%NOTFOUND;
      r_gmovi.fecha          := v_fec_actual;
      r_gmovi.hora           := v_hora;
      r_gmovi.fec_valor      := v_fec_actual;
      r_gmovi.cod_usuario    := user;
      r_gmovi.cod_ofi_origen := w_cdofici;
      r_gmovi.cod_oficina    := w_cdofici;
      r_gmovi.estado         := 'N';
      r_gmovi.reversado      := 'N';
      r_gmovi.protegido      := 'N';
      r_gmovi.emi_aviso      := 'N';
      r_gmovi.cod_mod_padre  := 7;
      r_gmovi.cod_mad_padre  := 71;
      r_gmovi.cod_tra_padre  := 800;
      r_gmovi.concepto       := 'Utilidad de Cambios';
      r_gmovi.cod_modulo     := 7;
      ----------------------------------------------------------------
      --1. Genera regitros en el GE_MOVIMIENTOS                            --
      ----------------------------------------------------------------
      IF NVL(W_UTILREF,0) <> 0 THEN
         /* PARAMETROS: Asiento, Nro.linea y moneda */
         LP_OBT_CTA_CONTABLE(786,1,W_CDMONED,W_CTCOREF,W_CDMNREF);
         IF W_UTILREF < 0 THEN /* perdida */
            W_DEBCRE := 'C';
         ELSE /* Ganancia */
            W_DEBCRE := 'D';
         END IF;
         IF W_CDMNREF = v_cod_mon_local THEN
            W_IMTRANS := ABS(W_UTILREF); W_IMPEQGS := 0;
         ELSE
            W_IMTRANS := 0;  W_IMPEQGS := ABS(W_UTILREF);
         END IF;
         IF W_CTCOREF IS NOT NULL THEN
            v_nro_secuencia       := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia := v_nro_secuencia;
            r_gmovi.cod_moneda    := w_cdmnref;
            r_gmovi.monto         := w_imtrans;
            r_gmovi.cod_rubro     := w_ctcoref;
            r_gmovi.mto_equ_local := w_impeqgs;
            r_gmovi.tip_mov_rubro := w_debcre;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            --GENERA_REG_GE_MOVIMIENTOS(W_CDMNREF,W_IMTRANS,W_CTCOREF,W_IMPEQGS,
            --                          W_DEBCRE,W_CDOFICI);
         END IF;
      END IF;
      -------------------------------------------------------------
      IF NVL(W_UTILNEF,0) <> 0 THEN
         IF W_UTILNEF > 0 THEN /* Ganancia */
            /* PARAMETROS: Asiento, Nro.linea y moneda */
            LP_OBT_CTA_CONTABLE(786,2,W_CDMONED,W_CTCONEF,W_CDMNNEF);
            W_DEBCRE := 'C';
         ELSE
            /* PARAMETROS: Asiento, Nro.linea y moneda */
            LP_OBT_CTA_CONTABLE(786,3,W_CDMONED,W_CTCONEF,W_CDMNNEF);
            W_DEBCRE := 'D';
         END IF;
         IF W_CDMNNEF = v_cod_mon_local THEN
            W_IMTRANS := ABS(W_UTILNEF); W_IMPEQGS := 0;
         ELSE
            W_IMTRANS := 0;  W_IMPEQGS := ABS(W_UTILNEF);
         END IF;
         IF W_CTCONEF IS NOT NULL THEN
            v_nro_secuencia       := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia := v_nro_secuencia;
            r_gmovi.cod_moneda    := W_CDMNNEF;
            r_gmovi.monto         := w_imtrans;
            r_gmovi.cod_rubro     := W_CTCONEF;
            r_gmovi.mto_equ_local := w_impeqgs;
            r_gmovi.tip_mov_rubro := w_debcre;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            --GENERA_REG_GE_MOVIMIENTOS(W_CDMNNEF,W_IMTRANS,W_CTCONEF,W_IMPEQGS,
            --                          W_DEBCRE,W_CDOFICI);
         END IF;
      END IF;
      -------------------------------------------------------------
      IF NVL(W_UTILRNE,0) <> 0 THEN
         /* PARAMETROS: Asiento, Nro.linea y moneda */
         LP_OBT_CTA_CONTABLE(789,1,W_CDMONED,W_CTCORNE,W_CDMNRNE);
         IF W_UTILRNE < 0 THEN /* perdida */
            W_DEBCRE := 'C';
         ELSE /* Ganancia */
            W_DEBCRE := 'D';
         END IF;
         IF W_CDMNRNE = v_cod_mon_local THEN
            W_IMTRANS := ABS(W_UTILRNE); W_IMPEQGS := 0;
         ELSE
            W_IMTRANS := 0;  W_IMPEQGS := ABS(W_UTILRNE);
         END IF;
         IF W_CTCORNE IS NOT NULL THEN
            v_nro_secuencia       := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia := v_nro_secuencia;
            r_gmovi.cod_moneda    := W_CDMNRNE;
            r_gmovi.monto         := w_imtrans;
            r_gmovi.cod_rubro     := W_CTCORNE;
            r_gmovi.mto_equ_local := w_impeqgs;
            r_gmovi.tip_mov_rubro := w_debcre;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            --GENERA_REG_GE_MOVIMIENTOS(W_CDMNRNE,W_IMTRANS,W_CTCORNE,W_IMPEQGS,
            --                          W_DEBCRE,W_CDOFICI);
         END IF;
      END IF;
      -------------------------------------------------------------
      IF NVL(W_UTILNNE,0) <> 0 THEN
         IF W_UTILNNE > 0 THEN /* Ganancia */
            /* PARAMETROS: Asiento, Nro.linea y moneda */
            LP_OBT_CTA_CONTABLE(789,2,W_CDMONED,W_CTCONNE,W_CDMNNNE);
            W_DEBCRE := 'C';
         ELSE
            /* PARAMETROS: Asiento, Nro.linea y moneda */
            LP_OBT_CTA_CONTABLE(789,3,W_CDMONED,W_CTCONNE,W_CDMNNNE);
            W_DEBCRE := 'D';
         END IF;
         IF W_CDMNNNE = v_cod_mon_local THEN
            W_IMTRANS := ABS(W_UTILNNE); W_IMPEQGS := 0;
         ELSE
            W_IMTRANS := 0;  W_IMPEQGS := ABS(W_UTILNNE);
         END IF;
         IF W_CTCONNE IS NOT NULL THEN
            v_nro_secuencia       := v_nro_secuencia + 1;
            r_gmovi.nro_secuencia := v_nro_secuencia;
            r_gmovi.cod_moneda    := W_CDMNNNE;
            r_gmovi.monto         := w_imtrans;
            r_gmovi.cod_rubro     := W_CTCONNE;
            r_gmovi.mto_equ_local := w_impeqgs;
            r_gmovi.tip_mov_rubro := w_debcre;
            pag_gen.pr_ins_ge_movimiento(r_gmovi,'N');
            --GENERA_REG_GE_MOVIMIENTOS(W_CDMNNNE,W_IMTRANS,W_CTCONNE,W_IMPEQGS,
            --                          W_DEBCRE,W_CDOFICI);
         END IF;
      END IF;
      -------------------------------------------------------------
   END LOOP;
   --IF MONEDA%ROWCOUNT = 0 THEN
   --   raise_application_error(-20000,'No existen datos a procesar.');
   --END IF;
   IF MONEDA%ISOPEN THEN
      CLOSE MONEDA;
   END IF;
END;
/

