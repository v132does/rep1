CREATE OR REPLACE PROCEDURE IT.PRG_GEN_EQU_DATOS (P_DATO        IN VARCHAR2 DEFAULT NULL   ,
                                               P_TIP_DATO    IN VARCHAR2 DEFAULT NULL   ,
                                               P_TIP_ARCHIVO IN VARCHAR2 DEFAULT 'TODOS') IS
    /*
    P_DATO    : Valor del Número de Cuenta o Código de Persona.-
    P_TIP_DATO: Tipo de Consulta, 'C': Por Cuenta o 'P': Por Persona (COD_PERSONA).-
    (S)       : Dato Obligadorio
    (N)       : Dato NO Obligatorio
    */

    v_fec_actual          ge_calendarios.fec_actual%type := PAG_CAL.FU_OBT_FEC_ACTUAL(6);
    v_fuldime             date;
    v_fprdime             date;
    v_monto               number(18,2);
    r_dat_persona         GE_EQU_PER_FISICAS%rowtype;
    r_dat_empresa         GE_EQU_PER_JURIDICAS%rowtype;
    r_dat_prestamos       GE_EQU_PRESTAMOS%rowtype;
    r_dat_tarjetas        GE_EQU_TARJETAS%rowtype;
    v_nro_secuencia       GE_EQU_PER_FISICAS.Nro_Secuencia%type;
    v_lugar               varchar2(3000);
    v_cod_persona         ba_personas.cod_persona%type;
    v_nro_cuenta          ge_cuentas.nro_cuenta%type;
    v_exi_tarjeta         varchar2(1) := 'S';
    v_tip_accion          varchar2(1) := 'I';
    v_tip_proceso         varchar2(1) := 'A';
    v_inf_PJ       VARCHAR2(1) := nvl(fug_obt_pardinamico('INF_PJ_ARC_EQUIFAX'),'N');
    v_cur_pre     varchar2(100);
    v_pri_vez         VARCHAR2(1) := nvl(fug_obt_pardinamico('INF_PRI_ARC_EQUIFAX'),'S');
    --Para personas fisicas *****************************************************
    CURSOR C_PRESTAMO_PF IS
          Select V_FEC_ACTUAL                       FECHA,
                 0                                  NRO_SECUENCIA,
                 to_char(A.COD_MODULO)              COD_MODULO,
                 to_char(A.COD_MODALIDAD)           COD_MODALIDAD,
                 A.NRO_CUENTA                       NRO_CUENTA,

                 FUE_OBT_VAL_MAX_REFCODES('TIP_PRE_EQUIFAX',a.tipo) TIP_PRESTAMO,--(S)
                 A.COD_MONEDA                       COD_MONEDA,       --(S)
                 to_char(round(A.MTO_CAPITAL))      MTO_CAPITAL,      --(S)
                 to_char(A.CAN_CUOTAS)              TOT_CUOTAS,       --(S)
                 null                               PER_PAGO,         --(S)
                 to_char(A.FEC_INICIO,'YYYYMMDD')   FEC_OTORGADO,     --(S)
                 null                               IDE_PRESTAMO,     --(N)
                 '0'                                COMP_MES,         --(S)
                 to_char(round(a.sal_capital + (a.sal_interes + a.sal_int_adelantado))) SAL_TOTAL,--(S)
                 '0'                               REFUERZOS,         --(N)
                 to_char(a.can_cuotas - nvl(a.can_cuo_pagadas, 0)) CAN_CUO_PENDIENTES,--(N)
                 '0'                               CUO_MES,           --(S)
                 '0'                               SAL_VENCIDO,       --(S)
                 '0'                               CAM_AUXILIAR_1,    --(N)
                 '0'                               CAM_AUXILIAR_2,    --(N)
                 '0'                               CAM_AUXILIAR_3,    --(N)
                 '0'                               CAM_AUXILIAR_4,    --(N)
                 '0'                               CAM_AUXILIAR_5,    --(N)
                 '0'                               CAM_AUXILIAR_6,    --(N)
                 '0'                               CAM_AUXILIAR_7,    --(N)
                 '0'                               CAM_AUXILIAR_8,    --(N)
                 '0'                               CAM_AUXILIAR_9,    --(N)
                 '0'                               CAM_AUXILIAR_10,   --(N)
                 '0'                               CAM_AUXILIAR_11,   --(N)
                 '0'                               CAM_AUXILIAR_12,   --(N)
                 a.fec_cancelacion                 FEC_CANCELACION ,
                 a.fec_inicio                      FEC_INICIO,
                 null                              tip_proceso,
                 substr(user,1,10)                 USU_INSERCION,
                 SYSDATE                           FEC_INSERCION,
                 substr(user,1,10)                 USU_MODIFICACION,
                 SYSDATE                           FEC_MODIFICACION,
                 'Normal'                          EST_DEUDA

          From pr_cta_prestamos a, (Select b.cod_modulo, b.cod_modalidad, b.nro_cuenta
                                      from ge_cta_clientes b ,ba_per_fisicas c
                                      where b.cod_modulo = 6
                                        and (nvl(V_COD_PERSONA,B.COD_PERSONA) = B.COD_PERSONA
                                        and  nvl(V_NRO_CUENTA ,B.NRO_CUENTA)  = B.NRO_CUENTA
                                         --Solo personas fisicas
                                       and (nvl(V_COD_PERSONA,B.COD_PERSONA) = c.COD_PERSONA)
                                       )                                       
                                      Group by b.cod_modulo, b.cod_modalidad, b.nro_cuenta) bx

          where fug_obt_pardinamico('PRO_ENV_EQUIFAX',a.cod_modulo,a.cod_modalidad) = 'S'
            and a.cod_modulo    = bx.cod_modulo
            and a.cod_modalidad = bx.cod_modalidad
            and a.nro_cuenta    = bx.nro_cuenta
            and ((a.estado              =  'N'
                  and a.fec_inicio      <  v_fprdime
                  and a.fec_cancelacion between v_fprdime and v_fuldime) -- Tener en cuenta todos los que se cancelaron en el mes

                  or a.estado <> 'N' and a.fec_inicio <= v_fec_actual)
         UNION
         -- HO -CROBPEFX-51 - Se agregan Operaciones Vencidas como Prestamos.
         Select V_FEC_ACTUAL                       FECHA,
                 0                                  NRO_SECUENCIA,
                 to_char(A.COD_MODULO)              COD_MODULO,
                 to_char(A.COD_MODALIDAD)           COD_MODALIDAD,
                 A.NRO_CUENTA                       NRO_CUENTA,
                 FUE_OBT_VAL_MAX_REFCODES('TIP_PRE_EQUIFAX','A') TIP_PRESTAMO,--(S)
                 A.COD_MONEDA                       COD_MONEDA,       --(S)
                 to_char(round(A.Mto_Origen))       MTO_CAPITAL,      --(S)
                 '1'                                TOT_CUOTAS,       --(S)
                 'M'                                PER_PAGO,         --(N)
                 to_char(a.fec_apertura,'YYYYMMDD') FEC_OTORGADO,     --(S)
                 null                               IDE_PRESTAMO,     --(N)
                 to_char(a.sal_total)               COMP_MES,          --(S)
                 to_char(a.sal_total)               SAL_TOTAL,         --(S)
                 '0'                               REFUERZOS,         --(N)
                 '1'                               CAN_CUO_PENDIENTES,--(N)
                 '1'                               CUO_MES,           --(S)
                 to_char(a.sal_total)              SAL_VENCIDO,       --(S)
                 '0'                               CAM_AUXILIAR_1,    --(N)
                 '0'                               CAM_AUXILIAR_2,    --(N)
                 '0'                               CAM_AUXILIAR_3,    --(N)
                 '0'                               CAM_AUXILIAR_4,    --(N)
                 '0'                               CAM_AUXILIAR_5,    --(N)
                 '0'                               CAM_AUXILIAR_6,    --(N)
                 '0'                               CAM_AUXILIAR_7,    --(N)
                 '0'                               CAM_AUXILIAR_8,    --(N)
                 '0'                               CAM_AUXILIAR_9,    --(N)
                 '0'                               CAM_AUXILIAR_10,   --(N)
                 '0'                               CAM_AUXILIAR_11,   --(N)
                 '0'                               CAM_AUXILIAR_12,   --(N)
                 null                              FEC_CANCELACION,
                 a.Fec_Apertura                    FEC_INICIO,
                 null                              tip_proceso,
                 substr(user,1,10)                 USU_INSERCION,
                 SYSDATE                           FEC_INSERCION,
                 substr(user,1,10)                 USU_MODIFICACION,
                 SYSDATE                           FEC_MODIFICACION,
                 'Normal'                          EST_DEUDA
          From ov_cta_vencidas a, (Select b.cod_modulo, b.cod_modalidad, b.nro_cuenta
                                      from ge_cta_clientes b,ba_per_fisicas c
                                      where b.cod_modulo = 15
                                        and (nvl(V_COD_PERSONA,B.COD_PERSONA) = B.COD_PERSONA
                                        and  nvl(V_NRO_CUENTA ,B.NRO_CUENTA)  = B.NRO_CUENTA
                                            --Solo personas fisicas
                                       and (nvl(V_COD_PERSONA,B.COD_PERSONA) = c.COD_PERSONA)
                                        )
                                      Group by b.cod_modulo, b.cod_modalidad, b.nro_cuenta) bx
          where fug_obt_pardinamico('PRO_ENV_EQUIFAX',a.cod_modulo,a.cod_modalidad) = 'S'
            and a.cod_modulo    = bx.cod_modulo
            and a.cod_modalidad = bx.cod_modalidad
            and a.nro_cuenta    = bx.nro_cuenta
            AND A.ESTADO <> 'C'
            and ((a.estado = 'N' and a.fec_apertura < v_fprdime)
                  or a.estado <> 'N' and a.fec_apertura <= v_fuldime
                );

         CURSOR C_TARJETAS_PF IS
          Select V_FEC_ACTUAL                       FECHA,
                 0                                  NRO_SECUENCIA,
                 to_char(A.COD_MODULO)              COD_MODULO,
                 to_char(A.COD_MODALIDAD)           COD_MODALIDAD,
                 A.NRO_CUENTA                       NRO_CUENTA,

                 FUE_OBT_VAL_MAX_REFCODES('REL_EQUIFAX_TC',a.cod_modalidad) TIP_TARJETA,--(S)
                 A.COD_MONEDA                       COD_MONEDA,         --(S)
                 TO_CHAR(nvl(ROUND(A.LIN_CREDITO),0))             LIM_CRE_CABECERA,   --(S)
                 '0'                                LIM_FINANCIACION,   --(S)
                 '0'                                LIM_RET_EFECTIVO,   --(S)
                 to_char(a.fec_apertura,'YYYYMMDD') FEC_EMISION,        --(S)
                 A.Nro_Cuenta||a.cod_moneda                               IDE_TARJETA,        --(N)
                 TO_CHAR(nvl(ROUND(a.mto_pag_minimo),0))          MTO_PAG_MINIMO,     --(S)
                  TO_CHAR(nvl(
                      ROUND(
                          CASE
                              WHEN (NVL(A.LIN_CREDITO, 0) -
                                    (NVL(A.SAL_FACTURAR, 0) +
                                     NVL(A.SAL_FACTURADO, 0) +
                                     NVL(A.SAL_FINANCIADO, 0) +
                                     NVL(A.SAL_CUO_PENDIENTES, 0))) < 0 THEN
                                  0
                              ELSE
                                  NVL(A.LIN_CREDITO, 0) -
                                  (NVL(A.SAL_FACTURAR, 0) +
                                   NVL(A.SAL_FACTURADO, 0) +
                                   NVL(A.SAL_FINANCIADO, 0) +
                                   NVL(A.SAL_CUO_PENDIENTES, 0))
                          END
                      ),0)
                  ) SAL_DISPONIBLE
                          , --(S)
                 '0'                                    TOT_COMP_MES,   --(S)--> No se importa el dato a IT-GF
                TO_CHAR(nvl(
                    ROUND(
                        CASE
                            WHEN (NVL(A.SAL_FACTURAR, 0) +
                                  NVL(A.SAL_FACTURADO, 0) +
                                  NVL(A.SAL_FINANCIADO, 0) +
                                  NVL(A.SAL_CUO_PENDIENTES, 0)) < 0 THEN
                                0
                            ELSE
                                NVL(A.SAL_FACTURAR, 0) +
                                NVL(A.SAL_FACTURADO, 0) +
                                NVL(A.SAL_FINANCIADO, 0) +
                                NVL(A.SAL_CUO_PENDIENTES, 0)
                        END
                    ),0)
                ) SAL_TOTAL        ,     --(S)
                TO_CHAR(nvl(
                      ROUND(
                          CASE
                              WHEN NVL(A.SAL_CUO_PENDIENTES, 0) < 0 THEN
                                  0
                              ELSE
                                  NVL(A.SAL_CUO_PENDIENTES, 0)
                          END
                      ),0)
                  ) SAL_CUOTAS,
                 TO_CHAR(nvl(
                      ROUND(
                          CASE
                              WHEN NVL(A.MTO_MORA, 0) < 0 THEN
                                  0
                              ELSE
                                  NVL(A.MTO_MORA, 0)
                          END
                      ),0)
                  ) SAL_VENCIDO,
                 '0'                                     IMP_CUO_MES_1, --(N)
                 '0'                                     IMP_CUO_MES_2, --(N)
                 '0'                                     IMP_CUO_MES_3, --(N)
                 '0'                                     IMP_CUO_MES_4, --(N)
                 '0'                                     IMP_CUO_MES_5, --(N)
                 '0'                                     IMP_CUO_MES_6, --(N)
                 '0'                                     IMP_CUO_MES_7, --(N)
                 '0'                                     IMP_CUO_MES_8, --(N)
                 '0'                                     IMP_CUO_MES_9, --(N)
                 '0'                                     IMP_CUO_MES_10,--(N)
                 '0'                                     IMP_CUO_MES_11,--(N)
                 '0'                                     IMP_CUO_MES_12,--(N)
                 a.fec_cancelacion                       FEC_CANCELACION,
                 a.FEC_APERTURA                          FEC_INICIO,
                 null                                    tip_proceso,
                 substr(user,1,10)                       USU_INSERCION,
                 SYSDATE                                 FEC_INSERCION,
                 substr(user,1,10)                       USU_MODIFICACION,
                 SYSDATE                                 FEC_MODIFICACION,
                 --- datos al cierre tarjeta
                TO_CHAR(nvl(sc.dia_atraso,0)) dia_atraso_cierre,
                TO_CHAR(nvl(sc.lin_credito,0) - ( nvl(sc.sal_facturar,0) + nvl(sc.sal_financiado,0) + nvl(sc.sal_cuo_pendientes,0) + nvl(sc.sal_facturado,0) )) limite_credito_cierre,
                '0' tot_compra_cierre,
                TO_CHAR( nvl(sc.sal_facturar,0) + nvl(sc.sal_financiado,0) + nvl(sc.sal_cuo_pendientes,0) + nvl(sc.sal_facturado,0) ) saldo_total_cierre,
                TO_CHAR(nvl(sc.sal_cuo_pendientes,0)) sal_cuo_pendientes_cierre,
                TO_CHAR(nvl(decode( a.tip_cobro,'M', CASE WHEN a.fec_ult_pago < a.fec_vct_ult_cierre then  sc.mto_pag_minimo ELSE 0 END ,'T', CASE WHEN a.fec_ult_pago < a.fec_vct_ult_cierre then  ( nvl(sc.sal_facturar,0) + nvl(sc.sal_financiado,0) + nvl( sc.sal_cuo_pendientes ,0) + nvl( sc.sal_facturado,0) ) ELSE 0 END),0)) saldo_vencido_cierre,
                TO_CHAR(nvl(sc.lin_credito,0)) lin_credito_cierre
          From ta_cta_tarjetas a, (Select b.cod_modulo, b.cod_modalidad, b.nro_cuenta
                                    from ge_cta_clientes b,ba_per_fisicas c
                                    where b.cod_modulo = 5
                                    and (nvl(V_COD_PERSONA,B.COD_PERSONA) = B.COD_PERSONA
                                     and nvl(V_NRO_CUENTA ,B.NRO_CUENTA ) = B.NRO_CUENTA
                                         --Solo personas fisicas
                                       and (nvl(V_COD_PERSONA,B.COD_PERSONA) = c.COD_PERSONA)
                                     )
                                    Group by b.cod_modulo, b.cod_modalidad, b.nro_cuenta) bx,
               (select s.nro_cuenta, s.sal_financiado, s.sal_facturado, s.sal_facturar, s.lin_credito, s.dia_atraso, s.sal_cuo_pendientes, s.mto_pag_minimo
                  from ta_sal_cierres s  where s.fec_cierre = (select max(s1.fec_cierre)
                                          from ta_sal_cierres s1
                                          where s1.nro_cuenta = s.nro_cuenta
                                          and to_char(s1.fec_cierre,'YYYYMM') <= to_char(v_fprdime,'YYYYMM')
                                        )
               ) sc
          where fug_obt_pardinamico('PRO_ENV_EQUIFAX',a.cod_modulo,a.cod_modalidad) = 'S'
            and a.cod_modulo    = bx.cod_modulo
            and a.cod_modalidad = bx.cod_modalidad
            and a.nro_cuenta    = bx.nro_cuenta
            and ((a.estado              =  'C'
                  and a.fec_apertura      <  v_fprdime
                  and a.fec_cancelacion between v_fprdime and v_fuldime)
                  or a.estado <> 'C'
                  ) and sc.nro_cuenta  (+)    = a.nro_cuenta;

    CURSOR C_INV_PERSONA_PF (P_CTA_PERSONA IN ge_cuentas.nro_cuenta%type) IS
         Select  v_fec_actual                  FECHA,
                 v_nro_secuencia               NRO_SECUENCIA,
                 --
                 null                          TIP_ACCION,     --(S)
                 to_char(c.cod_oficina)        COD_SUCURSAL,   --(S)
                 FUE_OBT_VAL_MAX_REFCODES('TIP_OPE_EQUIFAX', b.cod_modulo) tip_transaccion,--(S)
                 b.nro_cuenta      id_operacion,               --(S)
                 FUE_OBT_VAL_MAX_REFCODES('TIP_VIN_EQUIFAX', b.relacion)   tip_vinculacion,--(S)
                 a.cod_persona     nro_cliente,                --(N)
                 to_char(nvl(cu.dia_atraso, 0)) can_dia_atraso,--(S) ---
                 case when ((cu.cod_modulo = 6 and cu.estado = 'N') or (cu.cod_modulo <> 6 and cu.estado = 'C'))
                 and cu.fec_modificacion > v_fprdime then 'S' else 'N' end  ope_cerrada,  --(S)
                 to_char(v_fec_actual,'YYYYMM') periodo,       --(S)
                 'S' consentimiento,                           --(N)
                 null fec_valor,                               --(N)
                 decode((FUE_OBT_TIP_DOC_ABREVIATURA(a.cod_tip_documento)),'CI', 'CI', 'CRP', 'CRP', 'PAS', 'PAS', 'CRC') tip_documento,--(S)
                 decode(nvl(a.cod_pai_documento,1),1,'PY','OT')  pai_documento,--(S)
                 a.nro_documento nro_documento,                --(S)
                 null nacionalidad,                            --(N)
                 e.pri_apellido,                               --(S)
                 e.seg_apellido,                               --(N)
                 null ape_casada,                              --(N)
                 e.pri_nombre,                                 --(S)
                 e.seg_nombre,                                 --(N)
                 to_char(e.fec_nacimiento,'YYYYMMDD') fec_nacimiento,--(S)
                 null cod_sexo,                                --(N)
                 NULL est_civil,                               --(N)
                 NULL calle,                                   --(N)
                 null  nro_puerta,                             --(N)
                 null  apartamento,                            --(N)
                 null  piso,                                   --(N)
                 null  complemento,                            --(N)
                 null  kilometro,                              --(N)
                 null  manzana,                                --(N)
                 null  lote,                                   --(N)
                 null  block,                                  --(N)
                 null  esquina1,                               --(N)
                 null  esquina2,                               --(N)
                 null  pension,                                --(N)
                 null TIP_VIVIENDA,                            --(N)
                 null ID_CIUDAD,                               --(N)
                 null CIUDAD,                                  --(N)
                 null BARRIO,                                  --(N)
                 null DEPARTAMENTO,                            --(N)
                 null cod_postal,                              --(N)
                 null telefono,                                --(N)
                 null emp_empleo,                              --(N)
                 null cargo,                                   --(N)
                 null profesion,                               --(N)
                 null calle_laboral,                           --(N)
                 null nro_pue_laboral,                         --(N)
                 null apart_laboral,                           --(N)
                 null piso_laboral,                            --(N)
                 null comp_laboral,                            --(N)
                 null kilo_laboral,                            --(N)
                 null man_laboral,                             --(N)
                 null lote_laboral,                            --(N)
                 null blo_laboral,                             --(N)
                 null esq1_laboral,                            --(N)
                 null esq2_laboral,                            --(N)
                 null ID_CIU_LABORAL,                          --(N)
                 null CIU_LABORAL,                             --(N)
                 null LOC_LABORAL  ,                            --(N)
                 null DEP_LABORAL,                             --(N)
                 null cod_postal_lab,                          --(N)
                 null ING_EMPLEO,                              --(N)
                 null TEL_EMPLEO,                              --(N)
                 null tip_doc_conyuge,                         --(N)
                 null pai_doc_conyuge,                         --(N)
                 null nro_doc_conyuge,                         --(N)
                 null nac_conyuge,                             --(N)
                 null pri_ape_conyuge,                         --(N)
                 null seg_ape_conyuge,                         --(N)
                 null ape_cas_conyugue,                        --(N)
                 null pri_nom_conyuge,                         --(N)
                 null seg_nom_conyuge,                         --(N)
                 null tip_proceso,
                 substr(user,1,10) usu_insercion,
                 sysdate fec_insercion,
                 substr(user,1,10) usu_modificacion,
                 sysdate fec_modificacion
          from BA_PERSONAS     A,
               GE_CTA_CLIENTES B,
               GE_CLIENTES     C,
               BA_PER_FISICAS  E,
               BA_DIRECCIONES  f,
               GE_CUENTAS      CU
          where a.cod_persona    = b.cod_persona
            and a.cod_persona    = e.cod_persona
            and a.cod_persona    = f.cod_persona
            and f.principal      = 'S'
            and a.cod_persona    = c.cod_persona
            and cu.cod_modulo    = b.cod_modulo
            and cu.cod_modalidad = b.cod_modalidad
            and cu.nro_cuenta    = b.nro_cuenta
            and fug_obt_pardinamico('PRO_ENV_EQUIFAX',b.cod_modulo,b.cod_modalidad) = 'S'
            and b.nro_cuenta     = P_CTA_PERSONA
            and c.cli_especial   = 'N'
            and b.cod_persona    = NVL(V_COD_PERSONA,b.cod_persona);
    --*****************************************************************************
    --Para personas juridicas *****************************************************
    CURSOR C_INV_EMPRESAS (P_CTA_EMPRESAS IN ge_cuentas.nro_cuenta%type) IS
          Select v_fec_actual                  FECHA,
                 v_nro_secuencia               NRO_SECUENCIA,

                 null                          TIP_ACCION,   --(S)
                 to_char(c.cod_oficina)        COD_SUCURSAL, --(S)
                 FUE_OBT_VAL_MAX_REFCODES('TIP_OPE_EQUIFAX', b.cod_modulo) tip_transaccion,--(S)
                 b.nro_cuenta      id_operacion,             --(S)
                 FUE_OBT_VAL_MAX_REFCODES('TIP_VIN_EQUIFAX', b.relacion)   tip_vinculacion,--(S)
                 a.cod_persona     nro_cliente,              --(N)
                 to_char(nvl(cu.dia_atraso, 0)) can_dia_atraso,  --(S)
                 case when ((cu.cod_modulo = 6 and cu.estado = 'N') or (cu.cod_modulo <> 6 and cu.estado = 'C'))
                 and cu.fec_modificacion > v_fprdime then 'S' else 'N' end ope_cerrada,    --(S)
                 to_char(v_fec_actual,'YYYYMM') periodo,     --(S)
                 'S'              consentimiento,            --(N)
                 null              fec_valor,                --(N)
                 decode((FUE_OBT_TIP_DOC_ABREVIATURA(a.cod_tip_documento)),'RUC', 'RUC', 'CRC') tip_documento,    --(S)
                 decode(nvl(a.cod_pai_documento,1),1,'PY','OT')   cod_pai_documento,--(S)
                 to_char(a.nro_documento) nro_documento,     --(S)
                 j.raz_social             raz_social,        --(S)
                 a.nom_completo           nom_empresa,       --(N)
                 null                     act_comercial,     --(N)
                 null                     ini_actividades,   --(N)
                 null                     calle,             --(N)
                 null                     nro_puerta,        --(N)
                 null                     apartamento,       --(N)
                 null                     piso,              --(N)
                 null                     complemento,       --(N)
                 null                     kilometro,         --(N)
                 null                     manzana,           --(N)
                 null                     lote,              --(N)
                 null                     block,             --(N)
                 null                     esquina1,          --(N)
                 null                     esquina2,          --(N)
                 null                     tip_vivienda,      --(N)
                 null                     ID_CIUDAD,         --(N)
                 null                     CIUDAD,            --(N)
                 null                     barrio,            --(N)
                 null                     DEPARTAMENTO,      --(N)
                 null                     cod_postal,        --(N)
                 null                     telefono,          --(N)
                 null                     tip_proceso,
                 substr(user,1,10)        usu_insercion,
                 sysdate                  fec_insercion,
                 substr(user,1,10)        usu_modificacion,
                 sysdate                  fec_modificacion

          from BA_PERSONAS     A,
               GE_CTA_CLIENTES B,
               GE_CLIENTES     C,
               BA_PAISES       D,
               BA_DIRECCIONES  F,
               BA_CIUDADES     G,
               BA_PER_JURIDICAS J,
               GE_CUENTAS      CU
          where a.cod_persona = b.cod_persona
           and a.cod_pais     = d.cod_pais
           and a.cod_persona  = c.cod_persona
           and a.tipo         = 'J'
           and a.cod_persona  = f.cod_persona(+)
           and f.principal    = 'S'
           and f.cod_pais     = g.cod_pais
           and f.cod_ciudad   = g.cod_ciudad
           and cu.cod_modulo  = b.cod_modulo
           and cu.cod_modalidad = b.cod_modalidad
           and cu.nro_cuenta  = b.nro_cuenta
           and fug_obt_pardinamico('PRO_ENV_EQUIFAX',b.cod_modulo,b.cod_modalidad) = 'S'
           and b.nro_cuenta   = P_CTA_EMPRESAS
           and c.cli_especial = 'N'
           and b.cod_persona  = NVL(V_COD_PERSONA,b.cod_persona)
           and a.cod_persona  = j.cod_persona;
 
   CURSOR C_PRESTAMO_PJ IS
          Select V_FEC_ACTUAL                       FECHA,
                 0                                  NRO_SECUENCIA,
                 to_char(A.COD_MODULO)              COD_MODULO,
                 to_char(A.COD_MODALIDAD)           COD_MODALIDAD,
                 A.NRO_CUENTA                       NRO_CUENTA,

                 FUE_OBT_VAL_MAX_REFCODES('TIP_PRE_EQUIFAX',a.tipo) TIP_PRESTAMO,--(S)
                 A.COD_MONEDA                       COD_MONEDA,       --(S)
                 to_char(round(A.MTO_CAPITAL))      MTO_CAPITAL,      --(S)
                 to_char(A.CAN_CUOTAS)              TOT_CUOTAS,       --(S)
                 null                               PER_PAGO,         --(S)
                 to_char(A.FEC_INICIO,'YYYYMMDD')   FEC_OTORGADO,     --(S)
                 null                               IDE_PRESTAMO,     --(N)
                 '0'                                COMP_MES,         --(S)
                 to_char(round(a.sal_capital + (a.sal_interes + a.sal_int_adelantado))) SAL_TOTAL,--(S)
                 '0'                               REFUERZOS,         --(N)
                 to_char(a.can_cuotas - nvl(a.can_cuo_pagadas, 0)) CAN_CUO_PENDIENTES,--(N)
                 '0'                               CUO_MES,           --(S)
                 '0'                               SAL_VENCIDO,       --(S)
                 '0'                               CAM_AUXILIAR_1,    --(N)
                 '0'                               CAM_AUXILIAR_2,    --(N)
                 '0'                               CAM_AUXILIAR_3,    --(N)
                 '0'                               CAM_AUXILIAR_4,    --(N)
                 '0'                               CAM_AUXILIAR_5,    --(N)
                 '0'                               CAM_AUXILIAR_6,    --(N)
                 '0'                               CAM_AUXILIAR_7,    --(N)
                 '0'                               CAM_AUXILIAR_8,    --(N)
                 '0'                               CAM_AUXILIAR_9,    --(N)
                 '0'                               CAM_AUXILIAR_10,   --(N)
                 '0'                               CAM_AUXILIAR_11,   --(N)
                 '0'                               CAM_AUXILIAR_12,   --(N)
                 a.fec_cancelacion                 FEC_CANCELACION ,
                 a.fec_inicio                      FEC_INICIO,
                 null                              tip_proceso,
                 substr(user,1,10)                 USU_INSERCION,
                 SYSDATE                           FEC_INSERCION,
                 substr(user,1,10)                 USU_MODIFICACION,
                 SYSDATE                           FEC_MODIFICACION,
                 'Normal'                          EST_DEUDA

          From pr_cta_prestamos a, (Select b.cod_modulo, b.cod_modalidad, b.nro_cuenta
                                      from ge_cta_clientes b ,ba_per_JURIDICAS c
                                      where b.cod_modulo = 6
                                        and (nvl(V_COD_PERSONA,B.COD_PERSONA) = B.COD_PERSONA
                                        and  nvl(V_NRO_CUENTA ,B.NRO_CUENTA)  = B.NRO_CUENTA
                                         --Solo personas juridicas
                                       and (nvl(V_COD_PERSONA,B.COD_PERSONA) = c.COD_PERSONA)
                                       )                                       
                                      Group by b.cod_modulo, b.cod_modalidad, b.nro_cuenta) bx

          where fug_obt_pardinamico('PRO_ENV_EQUIFAX',a.cod_modulo,a.cod_modalidad) = 'S'
            and a.cod_modulo    = bx.cod_modulo
            and a.cod_modalidad = bx.cod_modalidad
            and a.nro_cuenta    = bx.nro_cuenta
            and ((a.estado              =  'N'
                  and a.fec_inicio      <  v_fprdime
                  and a.fec_cancelacion between v_fprdime and v_fuldime) -- Tener en cuenta todos los que se cancelaron en el mes

                  or a.estado <> 'N' and a.fec_inicio <= v_fec_actual)
         UNION
         -- HO -CROBPEFX-51 - Se agregan Operaciones Vencidas como Prestamos.
         Select V_FEC_ACTUAL                       FECHA,
                 0                                  NRO_SECUENCIA,
                 to_char(A.COD_MODULO)              COD_MODULO,
                 to_char(A.COD_MODALIDAD)           COD_MODALIDAD,
                 A.NRO_CUENTA                       NRO_CUENTA,
                 FUE_OBT_VAL_MAX_REFCODES('TIP_PRE_EQUIFAX','A') TIP_PRESTAMO,--(S)
                 A.COD_MONEDA                       COD_MONEDA,       --(S)
                 to_char(round(A.Mto_Origen))       MTO_CAPITAL,      --(S)
                 '1'                                TOT_CUOTAS,       --(S)
                 'M'                                PER_PAGO,         --(N)
                 to_char(a.fec_apertura,'YYYYMMDD') FEC_OTORGADO,     --(S)
                 null                               IDE_PRESTAMO,     --(N)
                 to_char(a.sal_total)               COMP_MES,          --(S)
                 to_char(a.sal_total)               SAL_TOTAL,         --(S)
                 '0'                               REFUERZOS,         --(N)
                 '1'                               CAN_CUO_PENDIENTES,--(N)
                 '1'                               CUO_MES,           --(S)
                 to_char(a.sal_total)              SAL_VENCIDO,       --(S)
                 '0'                               CAM_AUXILIAR_1,    --(N)
                 '0'                               CAM_AUXILIAR_2,    --(N)
                 '0'                               CAM_AUXILIAR_3,    --(N)
                 '0'                               CAM_AUXILIAR_4,    --(N)
                 '0'                               CAM_AUXILIAR_5,    --(N)
                 '0'                               CAM_AUXILIAR_6,    --(N)
                 '0'                               CAM_AUXILIAR_7,    --(N)
                 '0'                               CAM_AUXILIAR_8,    --(N)
                 '0'                               CAM_AUXILIAR_9,    --(N)
                 '0'                               CAM_AUXILIAR_10,   --(N)
                 '0'                               CAM_AUXILIAR_11,   --(N)
                 '0'                               CAM_AUXILIAR_12,   --(N)
                 null                              FEC_CANCELACION,
                 a.Fec_Apertura                    FEC_INICIO,
                 null                              tip_proceso,
                 substr(user,1,10)                 USU_INSERCION,
                 SYSDATE                           FEC_INSERCION,
                 substr(user,1,10)                 USU_MODIFICACION,
                 SYSDATE                           FEC_MODIFICACION,
                 'Normal'                          EST_DEUDA
          From ov_cta_vencidas a, (Select b.cod_modulo, b.cod_modalidad, b.nro_cuenta
                                      from ge_cta_clientes b,ba_per_juridicas c
                                      where b.cod_modulo = 15
                                        and (nvl(V_COD_PERSONA,B.COD_PERSONA) = B.COD_PERSONA
                                        and  nvl(V_NRO_CUENTA ,B.NRO_CUENTA)  = B.NRO_CUENTA
                                            --Solo personas juridicas
                                       and (nvl(V_COD_PERSONA,B.COD_PERSONA) = c.COD_PERSONA)
                                        )
                                      Group by b.cod_modulo, b.cod_modalidad, b.nro_cuenta) bx
          where fug_obt_pardinamico('PRO_ENV_EQUIFAX',a.cod_modulo,a.cod_modalidad) = 'S'
            and a.cod_modulo    = bx.cod_modulo
            and a.cod_modalidad = bx.cod_modalidad
            and a.nro_cuenta    = bx.nro_cuenta
            AND A.ESTADO <> 'C'
            and ((a.estado = 'N' and a.fec_apertura < v_fprdime)
                  or a.estado <> 'N' and a.fec_apertura <= v_fuldime
                );

         CURSOR C_TARJETAS_PJ IS
          Select V_FEC_ACTUAL                       FECHA,
                 0                                  NRO_SECUENCIA,
                 to_char(A.COD_MODULO)              COD_MODULO,
                 to_char(A.COD_MODALIDAD)           COD_MODALIDAD,
                 A.NRO_CUENTA                       NRO_CUENTA,

                 FUE_OBT_VAL_MAX_REFCODES('REL_EQUIFAX_TC',a.cod_modalidad) TIP_TARJETA,--(S)
                 A.COD_MONEDA                       COD_MONEDA,         --(S)
                 TO_CHAR(nvl(ROUND(A.LIN_CREDITO),0))             LIM_CRE_CABECERA,   --(S)
                 '0'                                LIM_FINANCIACION,   --(S)
                 '0'                                LIM_RET_EFECTIVO,   --(S)
                 to_char(a.fec_apertura,'YYYYMMDD') FEC_EMISION,        --(S)
                 A.Nro_Cuenta||a.cod_moneda                               IDE_TARJETA,        --(N)
                 TO_CHAR(nvl(ROUND(a.mto_pag_minimo),0))          MTO_PAG_MINIMO,     --(S)
                  TO_CHAR(nvl(
                      ROUND(
                          CASE
                              WHEN (NVL(A.LIN_CREDITO, 0) -
                                    (NVL(A.SAL_FACTURAR, 0) +
                                     NVL(A.SAL_FACTURADO, 0) +
                                     NVL(A.SAL_FINANCIADO, 0) +
                                     NVL(A.SAL_CUO_PENDIENTES, 0))) < 0 THEN
                                  0
                              ELSE
                                  NVL(A.LIN_CREDITO, 0) -
                                  (NVL(A.SAL_FACTURAR, 0) +
                                   NVL(A.SAL_FACTURADO, 0) +
                                   NVL(A.SAL_FINANCIADO, 0) +
                                   NVL(A.SAL_CUO_PENDIENTES, 0))
                          END
                      ),0)
                  ) SAL_DISPONIBLE
                          , --(S)
                 '0'                                    TOT_COMP_MES,   --(S)--> No se importa el dato a IT-GF
                TO_CHAR(nvl(
                    ROUND(
                        CASE
                            WHEN (NVL(A.SAL_FACTURAR, 0) +
                                  NVL(A.SAL_FACTURADO, 0) +
                                  NVL(A.SAL_FINANCIADO, 0) +
                                  NVL(A.SAL_CUO_PENDIENTES, 0)) < 0 THEN
                                0
                            ELSE
                                NVL(A.SAL_FACTURAR, 0) +
                                NVL(A.SAL_FACTURADO, 0) +
                                NVL(A.SAL_FINANCIADO, 0) +
                                NVL(A.SAL_CUO_PENDIENTES, 0)
                        END
                    ),0)
                ) SAL_TOTAL        ,     --(S)
                TO_CHAR(nvl(
                      ROUND(
                          CASE
                              WHEN NVL(A.SAL_CUO_PENDIENTES, 0) < 0 THEN
                                  0
                              ELSE
                                  NVL(A.SAL_CUO_PENDIENTES, 0)
                          END
                      ),0)
                  ) SAL_CUOTAS,
                 TO_CHAR(nvl(
                      ROUND(
                          CASE
                              WHEN NVL(A.MTO_MORA, 0) < 0 THEN
                                  0
                              ELSE
                                  NVL(A.MTO_MORA, 0)
                          END
                      ),0)
                  ) SAL_VENCIDO,
                 '0'                                     IMP_CUO_MES_1, --(N)
                 '0'                                     IMP_CUO_MES_2, --(N)
                 '0'                                     IMP_CUO_MES_3, --(N)
                 '0'                                     IMP_CUO_MES_4, --(N)
                 '0'                                     IMP_CUO_MES_5, --(N)
                 '0'                                     IMP_CUO_MES_6, --(N)
                 '0'                                     IMP_CUO_MES_7, --(N)
                 '0'                                     IMP_CUO_MES_8, --(N)
                 '0'                                     IMP_CUO_MES_9, --(N)
                 '0'                                     IMP_CUO_MES_10,--(N)
                 '0'                                     IMP_CUO_MES_11,--(N)
                 '0'                                     IMP_CUO_MES_12,--(N)
                 a.fec_cancelacion                       FEC_CANCELACION,
                 a.FEC_APERTURA                          FEC_INICIO,
                 null                                    tip_proceso,
                 substr(user,1,10)                       USU_INSERCION,
                 SYSDATE                                 FEC_INSERCION,
                 substr(user,1,10)                       USU_MODIFICACION,
                 SYSDATE                                 FEC_MODIFICACION,
                 --- datos al cierre tarjeta
                TO_CHAR(nvl(sc.dia_atraso,0)) dia_atraso_cierre,
                TO_CHAR(nvl(sc.lin_credito,0) - ( nvl(sc.sal_facturar,0) + nvl(sc.sal_financiado,0) + nvl(sc.sal_cuo_pendientes,0) + nvl(sc.sal_facturado,0) )) limite_credito_cierre,
                '0' tot_compra_cierre,
                TO_CHAR( nvl(sc.sal_facturar,0) + nvl(sc.sal_financiado,0) + nvl(sc.sal_cuo_pendientes,0) + nvl(sc.sal_facturado,0) ) saldo_total_cierre,
                TO_CHAR(nvl(sc.sal_cuo_pendientes,0)) sal_cuo_pendientes_cierre,
                TO_CHAR(nvl(decode( a.tip_cobro,'M', CASE WHEN a.fec_ult_pago < a.fec_vct_ult_cierre then  sc.mto_pag_minimo ELSE 0 END ,'T', CASE WHEN a.fec_ult_pago < a.fec_vct_ult_cierre then  ( nvl(sc.sal_facturar,0) + nvl(sc.sal_financiado,0) + nvl( sc.sal_cuo_pendientes ,0) + nvl( sc.sal_facturado,0) ) ELSE 0 END),0)) saldo_vencido_cierre,
                TO_CHAR(nvl(sc.lin_credito,0)) lin_credito_cierre
          From ta_cta_tarjetas a, (Select b.cod_modulo, b.cod_modalidad, b.nro_cuenta
                                    from ge_cta_clientes b,ba_per_juridicas c
                                    where b.cod_modulo = 5
                                    and (nvl(V_COD_PERSONA,B.COD_PERSONA) = B.COD_PERSONA
                                     and nvl(V_NRO_CUENTA ,B.NRO_CUENTA ) = B.NRO_CUENTA
                                         --Solo personas JURIDICAS
                                       and (nvl(V_COD_PERSONA,B.COD_PERSONA) = c.COD_PERSONA)
                                     )
                                    Group by b.cod_modulo, b.cod_modalidad, b.nro_cuenta) bx,
               (select s.nro_cuenta, s.sal_financiado, s.sal_facturado, s.sal_facturar, s.lin_credito, s.dia_atraso, s.sal_cuo_pendientes, s.mto_pag_minimo
                  from ta_sal_cierres s  where s.fec_cierre = (select max(s1.fec_cierre)
                                          from ta_sal_cierres s1
                                          where s1.nro_cuenta = s.nro_cuenta
                                          and to_char(s1.fec_cierre,'YYYYMM') <= to_char(v_fprdime,'YYYYMM')
                                        )
               ) sc
          where fug_obt_pardinamico('PRO_ENV_EQUIFAX',a.cod_modulo,a.cod_modalidad) = 'S'
            and a.cod_modulo    = bx.cod_modulo
            and a.cod_modalidad = bx.cod_modalidad
            and a.nro_cuenta    = bx.nro_cuenta
            and ((a.estado              =  'C'
                  and a.fec_apertura      <  v_fprdime
                  and a.fec_cancelacion between v_fprdime and v_fuldime)
                  or a.estado <> 'C'
                  ) and sc.nro_cuenta  (+)    = a.nro_cuenta;
      
    --Fin de Persona Juridica ******************************************************************
    PROCEDURE PR_INS_DATOS( p_tipo          IN VARCHAR2) IS
          BEGIN
               If p_tipo = 'F' Then
                  insert into GE_EQU_PER_FISICAS values r_dat_persona;
               ElsIf p_tipo = 'J' Then
                  insert into GE_EQU_PER_JURIDICAS values r_dat_empresa;
               ElsIf p_tipo = 'P' Then
                  insert into GE_EQU_PRESTAMOS values r_dat_prestamos;
               ElsIf p_tipo = 'T' Then
                  insert into GE_EQU_TARJETAS values r_dat_tarjetas;
               End If;
          Exception
               When others Then
                    raise_application_error(-20000,v_lugar||sqlerrm);
          END;
    FUNCTION FU_OBT_COMPROMISO (P_CTA_COMPROMISO IN VARCHAR2,
                                P_TIPO       IN VARCHAR2 ) return number IS
          v_monto number;
          BEGIN
               If P_TIPO = 'D' THEN --> Deuda Vencida del periodo anterior.-
                  Select sum(nvl(a.sal_capital,0) + nvl(a.sal_interes,0) + nvl(a.sal_int_documentado,0) + nvl(a.val_recargo,0)) com_mes
                    into v_monto
                    From pr_cuotas a, pr_cta_prestamos b
                   where a.nro_cuenta    = b.nro_cuenta
                     and (b.estado  <> 'N' or b.fec_cancelacion between v_fprdime and v_fuldime)
                     and a.nro_cuota     > 0
                     and ((a.estado <> 'N' and a.fec_vencimiento < v_fprdime))
                     and a.nro_cuenta    = P_CTA_COMPROMISO;
               ElsIf P_TIPO = 'C' Then --> Cuota Correspondiente al Mes.-
                  Select sum(nvl(a.mto_capital,0) + nvl(a.mto_interes,0) + nvl(a.mto_int_documentado,0) + nvl(a.val_recargo,0)) com_mes
                    into v_monto
                    From pr_cuotas a, pr_cta_prestamos b
                   where a.nro_cuenta      = b.nro_cuenta
                     and a.nro_cuota       > 0
                     and a.fec_vencimiento between v_fprdime and v_fuldime
                     and a.nro_cuenta      = P_CTA_COMPROMISO;
               ElsIf P_TIPO = 'S' Then --> Saldo Vencido
                  Select sum(nvl(a.sal_capital,0) + nvl(a.sal_interes,0) + nvl(a.sal_int_documentado,0) + nvl(a.val_recargo,0)) sal_mes
                    into v_monto
                    From pr_cuotas a, pr_cta_prestamos b
                   where a.nro_cuenta    = b.nro_cuenta
                     and (b.estado  <> 'N' or b.fec_cancelacion between v_fprdime and v_fuldime)
                     and a.nro_cuota     > 0
                     and (a.estado <> 'N' and a.fec_vencimiento < v_fec_actual)
                     and a.nro_cuenta    = P_CTA_COMPROMISO;
               End If;
               return nvl(v_monto,0);
          END;
     FUNCTION FUG_OBT_DIA_ATRASO (P_CTA_ATRASO  IN GE_CUENTAS.NRO_CUENTA%TYPE) RETURN NUMBER IS

         v_max_atraso pr_cta_prestamos.max_atraso%TYPE;

       BEGIN
            SELECT nvl(MAX(x.dia_atraso), 0)
              INTO v_max_atraso
              FROM GE_CLA_OPERACIONES_HIS x
             WHERE x.fecha       between v_fprdime and v_fuldime
               AND x.nro_cuenta  = P_CTA_ATRASO;

            RETURN v_max_atraso;
       EXCEPTION
           WHEN OTHERS THEN
                raise_application_error(-20000,'Al Obtener día de Atraso ' ||SQLERRM);
       END;

       FUNCTION fu_cal_periodicidad (P_CTA_COMPROMISO IN VARCHAR2)
            return varchar2 is
            v_fec_inicio      pr_cta_prestamos.fec_inicio%type;
            v_fec_vencimiento pr_cta_prestamos.fec_vencimiento%type;
            v_can_cuotas      pr_cta_prestamos.can_cuotas%type;
            v_can_dias        number;
            v_periodicidad    number;
            v_periodo         varchar2(1);

            begin
              begin
                  Select b.fec_inicio, b.fec_vencimiento, b.can_cuotas
                    into v_fec_inicio, v_fec_vencimiento, v_can_cuotas
                    From pr_cta_prestamos b
                   where b.nro_cuenta    = P_CTA_COMPROMISO;
              end;
              begin
                   select to_date(v_fec_vencimiento, 'DD/MM/YY') - to_date(v_fec_inicio, 'DD/MM/YY')
                   into v_can_dias from dual;

              exception
                when others then
                  v_can_dias := 0;
              end;
              v_periodicidad := nvl(round(v_can_dias/v_can_cuotas,0),0);

              begin
              case
                 WHEN v_periodicidad>=0 and v_periodicidad <= 7 THEN v_periodo :='L';
                 WHEN v_periodicidad>7 and v_periodicidad <= 15 THEN v_periodo :='Q';
                 WHEN v_periodicidad>15 and v_periodicidad <= 31 THEN v_periodo :='M';
                 WHEN v_periodicidad>31 and v_periodicidad <= 61 THEN v_periodo :='B';

                 WHEN v_periodicidad>61 and v_periodicidad <= 91 THEN v_periodo :='T';
                 WHEN v_periodicidad>91 and v_periodicidad <= 121 THEN v_periodo :='C';
                 WHEN v_periodicidad>121 and v_periodicidad <= 181 THEN v_periodo :='S';
                 WHEN v_periodicidad>181 and v_periodicidad <= 366 THEN v_periodo :='A';
                 ELSE v_periodo :='O';
              END CASE;
              end;
              return v_periodo;
    end;

    FUNCTION fu_val_letras(p_cadena IN VARCHAR2)-- valida conjunto de letras y caracteres permitidos
      RETURN VARCHAR2 IS
             v_cadena varchar2(4000);
    begin
             v_cadena := REGEXP_REPLACE(p_cadena, '[^ABCDEFGHIJKLMNOPQRSTUVWXYZñÑ''´ÄËÏÖÜäëïöüçÇ]', '');
             v_cadena := REPLACE(REPLACE(v_cadena, CHR(13), ''), CHR(10), '');
             return v_cadena;
    end fu_val_letras;

    FUNCTION fu_val_alf_ext_num_ent(p_cadena IN VARCHAR2) -- valida conjunto alfanumerico ext + numerico entero
      return varchar2 is
             v_cadena varchar2(4000);
    begin
             v_cadena := REGEXP_REPLACE(p_cadena, '[^ABCDEFGHIJKLMNOPQRSTUVWXYZñÑ@&;''-_/.*ÁÉÍÓÚ:ÄËÏÖÜº°,`()ªçÇ$´ &;0123456789.-]', '');
             return v_cadena;
    end;

    FUNCTION fu_obt_com_mes(p_nro_cuenta IN VARCHAR2)
    RETURN NUMBER IS
      v_total number(18,2);
    BEGIN
      begin
        select sum(t.mto_operacion) into v_total
        from ta_mov_especiales t
        where t.nro_cuenta  = p_nro_cuenta
        and t.fecha between v_fprdime and v_fuldime
        and t.cod_tip_cargo in (42,39,41,38) and t.procesado = 'S';
      exception
        when others then
        v_total   := 0;
      end;
      return nvl(v_total,0);
    END;

BEGIN
    BEGIN PRE_INI_APLICACION; PAE_CNF.G_COD_MODULO:= 1; END;
    v_fprdime     := last_day(add_months(v_fec_actual,-1)) + 1;
    v_fuldime     := last_day(v_fec_actual);

    If    nvl(P_TIP_DATO,'X') = 'C' Then
        v_nro_cuenta  := p_dato;
    ElsIf nvl(P_TIP_DATO,'X') = 'P' Then
        v_cod_persona := p_dato;
    End If;

    If nvl(pae_cnf.G_PROGRAMA,'X') = 'GEQUIFAX' Then
        v_tip_proceso := 'M';
        -- Borrar solo la cuenta o cliente re-procesado desde la pantalla.-
        declare
          cursor c_secdato is
            Select ax.nro_secuencia
              from ge_equ_per_fisicas ax
             where decode(nvl(P_TIP_DATO,'X'),'C',ax.id_operacion,ax.nro_cliente) = p_dato
             union
            select ax.nro_secuencia
              from ge_equ_per_juridicas ax
             where decode(nvl(P_TIP_DATO,'X'),'C',ax.id_operacion,ax.nro_cliente) = p_dato;
        begin
        for c in c_secdato loop
          Begin
              Insert into GE_EQU_PER_FISICAS_HIS
              Select * from GE_EQU_PER_FISICAS   a where a.nro_secuencia = c.nro_secuencia;

              Insert into GE_EQU_PER_JURIDICAS_HIS
              Select * from GE_EQU_PER_JURIDICAS b where b.nro_secuencia = c.nro_secuencia;

              Insert into GE_EQU_PRESTAMOS_HIS
              Select * from GE_EQU_PRESTAMOS     c where c.nro_secuencia = c.nro_secuencia;

              Insert into GE_EQU_TARJETAS_HIS
              Select * from GE_EQU_TARJETAS      d where d.nro_secuencia = c.nro_secuencia;
          Exception
              When Others Then
                   raise_application_error(-20000,'Al Trasladar al Histórico '||sqlerrm);
          End;

          delete GE_EQU_PER_FISICAS   a where a.nro_secuencia = c.nro_secuencia;

          delete GE_EQU_PER_JURIDICAS b where b.nro_secuencia = c.nro_secuencia;

          delete GE_EQU_PRESTAMOS     c where c.nro_secuencia = c.nro_secuencia;

          delete GE_EQU_TARJETAS      d where d.nro_secuencia = c.nro_secuencia;
        end loop;
        end;
    Else
        v_tip_proceso := 'A';
        Begin
            Insert into GE_EQU_PER_FISICAS_HIS   Select * from GE_EQU_PER_FISICAS;
            Insert into GE_EQU_PER_JURIDICAS_HIS Select * from GE_EQU_PER_JURIDICAS;
            Insert into GE_EQU_PRESTAMOS_HIS     Select * from GE_EQU_PRESTAMOS;
            Insert into GE_EQU_TARJETAS_HIS      Select * from GE_EQU_TARJETAS;
        Exception
            When Others Then
                 raise_application_error(-20000,'Al Trasladar al Histórico '||sqlerrm);
        End;

        execute immediate 'truncate table GE_EQU_PER_FISICAS';
        execute immediate 'truncate table GE_EQU_PER_JURIDICAS';
        execute immediate 'truncate table GE_EQU_PRESTAMOS';
        execute immediate 'truncate table GE_EQU_TARJETAS';
    End IF;

    Begin
        Select distinct(a.val_parametro)
          into v_exi_tarjeta
          From ge_par_dinamicos a
         where a.parametro  = 'PRO_ENV_EQUIFAX'
           and a.cod_modulo = 5
           and a.val_parametro  = 'S';
    Exception
        When no_data_found Then
             v_exi_tarjeta := 'N';
        When Others Then
             v_exi_tarjeta := 'N';
    End;
    --***** Para Personas Fisicas **********************************************************
    -- Inserción de Datos
    FOR i IN C_PRESTAMO_PF LOOP
         Begin
             SELECT S_NRO_REG_EQUIFAX.NEXTVAL INTO V_NRO_SECUENCIA FROM DUAL;
         End;
         --Definir el Tipo de Accion M: Modificación - I: Inclusión
         IF i.fec_inicio < v_fprdime Then
           IF nvl(v_pri_vez,'N') ='S'  then
             v_tip_accion := 'I';
           ELSE
             v_tip_accion := 'M';
           END IF;
         Else
            v_tip_accion := 'I';
         End If;
         -- Genero Datos de Personas Físicas
         FOR X IN C_INV_PERSONA_PF (NVL(V_NRO_CUENTA,I.NRO_CUENTA)) LOOP
             v_lugar := i.nro_cuenta||': Generando Datos de Personas Físicas ';
             r_dat_persona            := X;
             r_dat_persona.tip_accion := v_tip_accion;
             r_dat_persona.tip_proceso:= v_tip_proceso;
             r_dat_persona.pri_apellido := trim(fu_val_letras(x.pri_apellido));
             r_dat_persona.seg_apellido := trim(fu_val_letras(x.seg_apellido));
             r_dat_persona.pri_nombre   := trim(fu_val_letras(x.pri_nombre));
             r_dat_persona.seg_nombre   := trim(fu_val_letras(x.seg_nombre));
             pr_ins_datos('F');
         END LOOP;
         -- Genero Datos de Préstamos
         If i.cod_modulo = 6 Then
         v_lugar := i.nro_cuenta||': Generando Datos de Préstamos ';
         R_DAT_PRESTAMOS := i;
         r_dat_prestamos.nro_secuencia := V_NRO_SECUENCIA;
             r_dat_prestamos.per_pago      := fu_cal_periodicidad(i.nro_cuenta);
             r_dat_prestamos.Cuo_Mes       := FU_OBT_COMPROMISO(i.nro_cuenta,'C');
             r_dat_prestamos.Comp_Mes      := ROUND((FU_OBT_COMPROMISO(i.nro_cuenta,'D')) + r_dat_prestamos.cuo_mes);
             r_dat_prestamos.cuo_mes       := ROUND(r_dat_prestamos.cuo_mes);
             r_dat_prestamos.sal_vencido   := ROUND(FU_OBT_COMPROMISO(i.nro_cuenta,'S'));
             r_dat_prestamos.tip_proceso   := v_tip_proceso;
             pr_ins_datos('P');
         End IF;
    END LOOP;
    -- Tarjetas PF
    IF V_EXI_TARJETA = 'S' THEN
        FOR i IN C_TARJETAS_PF LOOP
             Begin
                 SELECT S_NRO_REG_EQUIFAX.NEXTVAL INTO V_NRO_SECUENCIA FROM DUAL;
             End;
             --Definir el Tipo de Accion M: Modificación - I: Inclusión
             IF i.fec_inicio < v_fprdime Then
                 IF nvl(v_pri_vez,'N') ='S'  then
                     v_tip_accion := 'I';
                 ELSE
                    v_tip_accion := 'M';
                 END IF;
             Else
                v_tip_accion := 'I';
             End If;
             -- Genero Datos de Personas Físicas
             FOR X IN C_INV_PERSONA_PF (NVL(V_NRO_CUENTA,I.NRO_CUENTA)) LOOP
                 v_lugar := i.nro_cuenta||': Generando Datos de Personas Físicas ';
                 r_dat_persona            := X;
                 r_dat_persona.tip_accion := v_tip_accion;
                 r_dat_persona.tip_proceso:= v_tip_proceso;
                 pr_ins_datos('F');
             END LOOP;
             -- Genero Datos de Tarjetas
             If i.cod_modulo = 5 Then
                v_lugar := i.nro_cuenta||': Generando Datos de Tarjetas '||i.fec_cancelacion;
                r_dat_tarjetas               := i;
                if to_number(r_dat_tarjetas.dia_atr_cierre) < 0  then
                  r_dat_tarjetas.dia_atr_cierre := '0';
                end if;
                if to_number(r_dat_tarjetas.lim_cre_dis_cie) < 0  then
                  r_dat_tarjetas.lim_cre_dis_cie := '0';
                end if;
                if to_number(r_dat_tarjetas.lim_cre_dis_cie) > to_number(r_dat_tarjetas.lim_cre_cabecera) then
                   r_dat_tarjetas.lim_cre_dis_cie := r_dat_tarjetas.lim_cre_cabecera;
                end if;
                r_dat_tarjetas.tot_com_cierre := fu_obt_com_mes(i.nro_cuenta);
                if to_number(r_dat_tarjetas.sal_tot_cierre) < 0  then
                  r_dat_tarjetas.sal_tot_cierre := '0';
                end if;
                if to_number(r_dat_tarjetas.sal_cuo_cierre) < 0  then
                  r_dat_tarjetas.sal_cuo_cierre := '0';
                end if;
                if to_number(r_dat_tarjetas.sal_ven_cierre) < 0  then
                  r_dat_tarjetas.sal_ven_cierre := '0';
                end if;
                if to_number(r_dat_tarjetas.lim_cre_cierre) < 0  then
                  r_dat_tarjetas.lim_cre_cierre := '0';
                end if;
                r_dat_tarjetas.nro_secuencia := V_NRO_SECUENCIA;
                r_dat_tarjetas.tip_proceso   := v_tip_proceso;
                pr_ins_datos('T');
             End If;
        END LOOP;
    END IF;
   --***************************************************************************************
   
   --*****Para Personas Juridicas **********************************************************
   IF nvl(v_inf_PJ,'N')='S' then
           -- Inserción de Datos
          FOR i IN C_PRESTAMO_PJ LOOP
               Begin
                   SELECT S_NRO_REG_EQUIFAX.NEXTVAL INTO V_NRO_SECUENCIA FROM DUAL;
               End;
               --Definir el Tipo de Accion M: Modificación - I: Inclusión
               IF i.fec_inicio < v_fprdime Then
                   IF nvl(v_pri_vez,'N') ='S'  then
                     v_tip_accion := 'I';
                   ELSE
                     v_tip_accion := 'M';
                   END IF;
               Else
                  v_tip_accion := 'I';
               End If;

               -- Genero Datos de Personas Jurídicas
                 FOR W IN C_INV_EMPRESAS (NVL(V_NRO_CUENTA,I.NRO_CUENTA)) LOOP
                     v_lugar := i.nro_cuenta||' : Generando Datos de Personas Jurídicas ';
                     r_dat_empresa            := W;
                     r_dat_empresa.tip_accion := v_tip_accion;
                     r_dat_empresa.tip_proceso:= v_tip_proceso;
                     r_dat_empresa.raz_social := trim(fu_val_alf_ext_num_ent(w.raz_social));
                     r_dat_empresa.nom_empresa:= trim(fu_val_alf_ext_num_ent(w.nom_empresa));
                     pr_ins_datos('J');
                 END LOOP;

               -- Genero Datos de Préstamos
               If i.cod_modulo = 6 Then
               v_lugar := i.nro_cuenta||': Generando Datos de Préstamos ';
               R_DAT_PRESTAMOS := i;
               r_dat_prestamos.nro_secuencia := V_NRO_SECUENCIA;
                   r_dat_prestamos.per_pago      := fu_cal_periodicidad(i.nro_cuenta);
                   r_dat_prestamos.Cuo_Mes       := FU_OBT_COMPROMISO(i.nro_cuenta,'C');
                   r_dat_prestamos.Comp_Mes      := ROUND((FU_OBT_COMPROMISO(i.nro_cuenta,'D')) + r_dat_prestamos.cuo_mes);
                   r_dat_prestamos.cuo_mes       := ROUND(r_dat_prestamos.cuo_mes);
                   r_dat_prestamos.sal_vencido   := ROUND(FU_OBT_COMPROMISO(i.nro_cuenta,'S'));
                   r_dat_prestamos.tip_proceso   := v_tip_proceso;
                   pr_ins_datos('P');
               End IF;
          END LOOP;
          
    -- Tarjetas PJ
    IF V_EXI_TARJETA = 'S' THEN
        FOR i IN C_TARJETAS_PJ LOOP
             Begin
                 SELECT S_NRO_REG_EQUIFAX.NEXTVAL INTO V_NRO_SECUENCIA FROM DUAL;
             End;
             --Definir el Tipo de Accion M: Modificación - I: Inclusión
             IF i.fec_inicio < v_fprdime Then
                 IF nvl(v_pri_vez,'N') ='S'  then
                   v_tip_accion := 'I';
                 ELSE
                   v_tip_accion := 'M';
                 END IF;
             Else
                v_tip_accion := 'I';
             End If;
             -- Genero Datos de Personas Jurídicas
             IF nvl(v_inf_PJ,'N')='S' then
                 FOR W IN C_INV_EMPRESAS (NVL(V_NRO_CUENTA,I.NRO_CUENTA)) LOOP
                     v_lugar := i.nro_cuenta||' : Generando Datos de Personas Jurídicas ';
                     r_dat_empresa            := W;
                     r_dat_empresa.tip_accion := v_tip_accion;
                     r_dat_empresa.tip_proceso:= v_tip_proceso;
                     pr_ins_datos('J');
                 END LOOP;
             end if;
             -- Genero Datos de Tarjetas
             If i.cod_modulo = 5 Then
                v_lugar := i.nro_cuenta||': Generando Datos de Tarjetas '||i.fec_cancelacion;
                r_dat_tarjetas               := i;
                if to_number(r_dat_tarjetas.dia_atr_cierre) < 0  then
                  r_dat_tarjetas.dia_atr_cierre := '0';
                end if;
                if to_number(r_dat_tarjetas.lim_cre_dis_cie) < 0  then
                  r_dat_tarjetas.lim_cre_dis_cie := '0';
                end if;
                if to_number(r_dat_tarjetas.lim_cre_dis_cie) > to_number(r_dat_tarjetas.lim_cre_cabecera) then
                   r_dat_tarjetas.lim_cre_dis_cie := r_dat_tarjetas.lim_cre_cabecera;
                end if;
                r_dat_tarjetas.tot_com_cierre := fu_obt_com_mes(i.nro_cuenta);
                if to_number(r_dat_tarjetas.sal_tot_cierre) < 0  then
                  r_dat_tarjetas.sal_tot_cierre := '0';
                end if;
                if to_number(r_dat_tarjetas.sal_cuo_cierre) < 0  then
                  r_dat_tarjetas.sal_cuo_cierre := '0';
                end if;
                if to_number(r_dat_tarjetas.sal_ven_cierre) < 0  then
                  r_dat_tarjetas.sal_ven_cierre := '0';
                end if;
                if to_number(r_dat_tarjetas.lim_cre_cierre) < 0  then
                  r_dat_tarjetas.lim_cre_cierre := '0';
                end if;
                r_dat_tarjetas.nro_secuencia := V_NRO_SECUENCIA;
                r_dat_tarjetas.tip_proceso   := v_tip_proceso;
                pr_ins_datos('T');
             End If;
        END LOOP;
     end if;
    end if;
    --***************************************************************************************
    COMMIT;
   PRG_GEN_ARC_EQUIFAX(NVL(P_TIP_ARCHIVO,'TODOS'),
                        V_TIP_PROCESO);
    COMMIT;
EXCEPTION
    When Others Then
         raise_application_error(-20000,'Error '||v_lugar||sqlerrm);
END;
/
