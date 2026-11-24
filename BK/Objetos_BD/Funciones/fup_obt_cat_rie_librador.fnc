create or replace function it.fup_obt_cat_rie_librador(p_nro_documento in varchar2,
                                                       p_tip_documento in varchar2,
                                                       p_tot_mto_deuda out number)
                                                       return number is
  --Requerimiento CORECLAS-1 / Clasificacion de Libradores--
  --Para obtener la clasificacion de clientes que solo son firmantes--
  --sin ser clientes, o son clientes, sin operaciones de creditos--

  --Variable de Fecha--
  v_cat_librador ge_clientes.cat_automatica%type;

begin
   SELECT MAX(CASE
       WHEN NVL(DLI.DEU_TOT_GS,0) > 0 THEN DLI.CAT_CLI
       ELSE CASE
            WHEN (S.FEC_ACTUAL - W.FEC_VENCIMIENTO) <= 0 THEN 1
            ELSE N.CAT_AUTOMATICA END
       END) LI_CAT_FINAL,
       SUM(NVL(fub_con_mon_a_moneda(A.COD_MONEDA,PAG_GEN.FU_OBT_MON_LOCAL, A.MONTO),0))
       into v_cat_librador, p_tot_mto_deuda
      FROM GE_CHE_CUSTODIAS A, PR_CTA_PRESTAMOS X, GE_CTA_CLIENTES K,
           GE_CLA_OPERACIONES N, PR_REL_CHQ_LIB B, PR_CHQ_LIBRADORES C,
           BA_TIP_DOCUMENTOS F, PR_CUOTAS W, BA_PERSONAS J, GE_CALENDARIOS S,
      (SELECT CLI.COD_PERSONA,
             MAX(CLI.CAT_AUTOMATICA) CAT_CLI,
             COUNT(*) CAN_DEU,
             SUM(NVL(OLI.TOT_DEU_REAL,0) + NVL(OLI.TOT_DEU_CONTINGENTE,0)) DEU_TOT_GS
      FROM GE_CLA_OPERACIONES OLI, GE_CLIENTES CLI
      WHERE CLI.COD_PERSONA = OLI.COD_PERSONA
      GROUP BY CLI.COD_PERSONA) DLI
      WHERE A.ESTADO IN ('C','A','B') --C-Custodia/ A-En Compensacion/ B-Devuelto - DYDMR-15030 NAF 04/2021
        AND X.NRO_CUENTA = A.NRO_REFERENCIA
        AND K.NRO_CUENTA = X.NRO_CUENTA
        AND K.RELACION = 'P'
        AND N.NRO_CUENTA = A.NRO_REFERENCIA
        AND W.NRO_CUENTA = A.NRO_REFERENCIA
        AND W.NRO_CUOTA = A.NRO_CUOTA
        AND W.ESTADO <> 'N'
        AND X.ESTADO <> 'N'
        AND nvl(fup_obt_tip_descuento(x.cod_modalidad), 'X') IN ('D','C')
        AND B.COD_BANCO = A.COD_BANCO
        AND B.NRO_CHEQUE = A.NRO_CHEQUE
        AND B.CTA_LIBRADORA = A.CTA_LIBRADORA
        AND C.NRO_DOCUMENTO = B.NRO_DOCUMENTO
        AND C.COD_TIP_DOCUMENTO = B.COD_TIP_DOCUMENTO
        AND F.COD_TIP_DOCUMENTO = C.COD_TIP_DOCUMENTO
        AND J.COD_TIP_DOCUMENTO(+) = C.COD_TIP_DOCUMENTO
        AND J.NRO_DOCUMENTO(+) = C.NRO_DOCUMENTO
        AND S.COD_MODULO = 6
        AND DLI.COD_PERSONA(+) = J.COD_PERSONA
        --Condicion--
        AND C.NRO_DOCUMENTO = p_nro_documento
        AND F.ABREVIATURA = p_tip_documento;
        -- BSEVOCORE-365 NAF 2020/01 se incluyen codeudores no clientes de descuento de documentos
        if v_cat_librador is null then
            SELECT MAX(CASE
               WHEN NVL(DLI.DEU_TOT_GS,0) > 0 THEN DLI.CAT_CLI
               ELSE CASE
                    WHEN (S.FEC_ACTUAL - W.FEC_VENCIMIENTO) <= 0 THEN 1
                    ELSE N.CAT_AUTOMATICA END
               END) LI_CAT_FINAL,
               SUM(NVL(fub_con_mon_a_moneda(p.COD_MONEDA,PAG_GEN.FU_OBT_MON_LOCAL, p.monto),0))
               
               into v_cat_librador, p_tot_mto_deuda
              FROM  PR_CTA_PRESTAMOS X, GE_CTA_CLIENTES K,
                       GE_CLA_OPERACIONES N, PR_DOCUMENTOS P,
                       PR_CUOTAS W, BA_PERSONAS J, GE_CALENDARIOS S,
                              (SELECT CLI.COD_PERSONA,
                                     MAX(CLI.CAT_AUTOMATICA) CAT_CLI,
                                     COUNT(*) CAN_DEU,
                                     SUM(NVL(OLI.TOT_DEU_REAL,0) + NVL(OLI.TOT_DEU_CONTINGENTE,0)) DEU_TOT_GS
                              FROM GE_CLA_OPERACIONES OLI, GE_CLIENTES CLI
                              WHERE CLI.COD_PERSONA = OLI.COD_PERSONA
                              GROUP BY CLI.COD_PERSONA) DLI,
                       (select distinct substr(t.nro_operacion,1,10) nro_operacion, 
                         t.nro_documento, t.tip_documento
                        from sb_crc_vinculos_det t where t.tip_vinculo = 6) v
                  WHERE K.NRO_CUENTA = X.NRO_CUENTA
                    AND K.RELACION = 'P'
                    AND N.NRO_CUENTA = x.nro_cuenta
                    AND W.NRO_CUENTA = x.nro_cuenta
                    AND W.NRO_CUOTA = p.NRO_CUOTA
                    AND W.ESTADO <> 'N'
                    AND X.ESTADO <> 'N'
                    AND nvl(fup_obt_tip_descuento(x.cod_modalidad), 'X') IN ('D','C')
                    AND S.COD_MODULO = 6
                    AND DLI.COD_PERSONA = J.COD_PERSONA
                    and p.nro_referencia = x.nro_cuenta
                    and k.cod_persona = j.cod_persona
                    and v.nro_operacion = x.nro_cuenta                    
                    and p.nro_documento = v.nro_documento
                    --Condicion--
                    and p.nro_documento = p_nro_documento
                   AND v.tip_documento = decode( p_tip_documento,'CI',p_tip_documento,'CRC')
                   ;
        end if;
        
   return v_cat_librador;
EXCEPTION
    WHEN OTHERS THEN
         raise_application_error(-20000,'Error en fup_obt_cat_rie_librador - '||sqlerrm);
end;
/

