create or replace force view it.tv_tar_seg as
Select C.COD_PERSONA,
               C.NRO_CUENTA,
               C.NRO_TARJETA,
               FUE_OBT_NOM_PERSONA(C.COD_PERSONA) NOMBRE_PERSONA,
               FUE_OBT_NRO_DOC_PERSONA(C.COD_PERSONA) NRO_DOC,
               C.COD_ESTADO,
               (Select T.DESCRIPCION
                  From TA_TAR_ESTADOS T
                 Where T.COD_ESTADO = C.COD_ESTADO) ESTADO,
               S.COD_CANAL,
               FUG_OBT_DES_CANAL(S.COD_CANAL) CANAL,
               NVL(A.COD_CAMPANA, S.COD_CAMPANA) COD_CAMPANA,
               A.DESCRIPCION CAMPANA,
               FUG_OBT_COD_USU_OFICIAL(C.COD_PERSONA) COD_USU_OFICIAL,
               FUE_OBT_NOM_USUARIO(FUG_OBT_COD_USU_OFICIAL(C.COD_PERSONA)) GESTOR,
               FUG_OBT_OFI_OFICIAL(C.COD_PERSONA) OFI_GESTOR,
               FUE_OBT_DES_OFICINA(FUG_OBT_OFI_OFICIAL(C.COD_PERSONA)) DES_OFI_GESTOR,
               DECODE(D.AFINIDAD, Null, Null,
                      FUG_OBT_DES_AFINIDAD(D.AFINIDAD)) DES_AFINIDAD,
               DECODE(D.SUB_AFINIDAD, Null, Null,
                      FUE_OBT_DES_REFCODES('SUB_AFINIDAD', D.SUB_AFINIDAD)) SUB_AFINIDAD,
               FUE_OBT_DES_REFCODES('RELACION', T.RELACION) RELACION,
               (Select Min(H.FECHA)
                  From TA_MOVIMIENTOS_HIS H
                 Where H.NRO_CUENTA = T.NRO_CUENTA) FEC_PRI_COMPRA,
               D.FEC_APERTURA,
               C.FEC_EMISION,
               D.LIN_CREDITO,
               (NVL(D.SAL_FACTURAR, 0) + NVL(D.SAL_FINANCIADO, 0) +
               NVL(D.SAL_FACTURADO, 0)) TOT_DEU,
               S.COD_USU_PROMOTOR COD_USU_PROMOTOR,
               FUE_OBT_NOM_USUARIO(S.COD_USU_PROMOTOR) NOM_USU_PROMOTOR,
               FUE_OBT_NOM_USUARIO(S.USU_INSERCION) USU_INSERCION,
               C.FEC_ACTIVACION,
               FUG_OBT_DES_EST_CTA(D.COD_MODULO, D.COD_MODALIDAD, D.ESTADO) TAR_ACTIV_ESTADO,
               FUE_OBT_DES_REFCODES('TIP_EMBOZADO',
                                    (Select NVL(T.TIP_ULT_EMBOZADO, 'X')
                                        From TA_TARJETAS_TMP T
                                       Where T.NRO_CUENTA = C.NRO_CUENTA
                                         And T.NRO_TARJETA = C.NRO_TARJETA
                                         And ROWNUM = 1)) TAR_TIP_DESC,
               S.OBSERVACION
          From TA_TARJETAS     C,
               TA_CTA_TARJETAS D,
               GE_CTA_CLIENTES T,
               CR_CAMPANAS     A,
               TA_SOLICITUDES  S
         Where C.NRO_CUENTA = D.NRO_CUENTA
           And C.NRO_CUENTA = T.NRO_CUENTA
           And C.COD_PERSONA = T.COD_PERSONA
           And D.NRO_SOLICITUD = S.NRO_SOLICITUD(+)
           And A.COD_CAMPANA(+) = S.COD_CAMPANA
           And not exists (Select 1 from ta_sol_adicionales ta
                           where ta.cod_persona = c.cod_persona
                             and (ta.nro_cuenta = c.nro_cuenta
                                  OR ta.nro_solicitud = d.nro_solicitud))
           And NVL(INSTR(FUG_OBT_PARDINAMICO('COD_AFI_SEG_TAR'), D.AFINIDAD),0) = 0

    Union All

  -- Tarjetas Personales SOLO para Tarjetas Adicionales
  Select distinct C.COD_PERSONA,
               C.NRO_CUENTA,
               C.NRO_TARJETA,
               FUE_OBT_NOM_PERSONA(C.COD_PERSONA) NOMBRE_PERSONA,
               FUE_OBT_NRO_DOC_PERSONA(C.COD_PERSONA) NRO_DOC,
               C.COD_ESTADO,
               (Select T.DESCRIPCION
                  From TA_TAR_ESTADOS T
                 Where T.COD_ESTADO = C.COD_ESTADO) ESTADO,
               S.COD_CANAL,
               FUG_OBT_DES_CANAL(S.COD_CANAL) CANAL,
               NVL(A.COD_CAMPANA, S.COD_CAMPANA) COD_CAMPANA,
               A.DESCRIPCION CAMPANA,
               FUG_OBT_COD_USU_OFICIAL(C.COD_PERSONA) COD_USU_OFICIAL,
               FUE_OBT_NOM_USUARIO(FUG_OBT_COD_USU_OFICIAL(C.COD_PERSONA)) GESTOR,
               FUG_OBT_OFI_OFICIAL(C.COD_PERSONA) OFI_GESTOR,
               FUE_OBT_DES_OFICINA(FUG_OBT_OFI_OFICIAL(C.COD_PERSONA)) DES_OFI_GESTOR,
               DECODE(D.AFINIDAD, Null, Null,
                      FUG_OBT_DES_AFINIDAD(D.AFINIDAD)) DES_AFINIDAD,
               DECODE(D.SUB_AFINIDAD, Null, Null,
                      FUE_OBT_DES_REFCODES('SUB_AFINIDAD', D.SUB_AFINIDAD)) SUB_AFINIDAD,
               FUE_OBT_DES_REFCODES('RELACION', T.RELACION) RELACION,
               (Select Min(H.FECHA)
                  From TA_MOVIMIENTOS_HIS H
                 Where H.NRO_CUENTA = T.NRO_CUENTA) FEC_PRI_COMPRA,
               D.FEC_APERTURA,
               C.FEC_EMISION,
               D.LIN_CREDITO,
               (NVL(D.SAL_FACTURAR, 0) + NVL(D.SAL_FINANCIADO, 0) +
               NVL(D.SAL_FACTURADO, 0)) TOT_DEU,
               decode(T.RELACION, 'A', ts.Cod_Usu_Promotor, S.COD_USU_PROMOTOR) COD_USU_PROMOTOR,
               FUE_OBT_NOM_USUARIO(decode(T.RELACION, 'A', ts.Cod_Usu_Promotor, S.COD_USU_PROMOTOR)) NOM_USU_PROMOTOR,
               FUE_OBT_NOM_USUARIO(S.USU_INSERCION) USU_INSERCION,
               C.FEC_ACTIVACION,
               FUG_OBT_DES_EST_CTA(D.COD_MODULO, D.COD_MODALIDAD, D.ESTADO) TAR_ACTIV_ESTADO,
               FUE_OBT_DES_REFCODES('TIP_EMBOZADO',
                                    (Select NVL(T.TIP_ULT_EMBOZADO, 'X')
                                        From TA_TARJETAS_TMP T
                                       Where T.NRO_CUENTA = C.NRO_CUENTA
                                         And T.NRO_TARJETA = C.NRO_TARJETA
                                         And ROWNUM = 1)) TAR_TIP_DESC,
               decode(T.RELACION, 'A', ts.Observacion, S.OBSERVACION) OBSERVACION
          From TA_TARJETAS     C,
               TA_CTA_TARJETAS D,
               GE_CTA_CLIENTES T,
               CR_CAMPANAS     A,
               TA_SOLICITUDES  S,
               TA_SOL_ADICIONALES ts
         Where C.NRO_CUENTA = D.NRO_CUENTA
           And C.NRO_CUENTA = T.NRO_CUENTA
           And C.COD_PERSONA = T.COD_PERSONA
           And D.Nro_Solicitud = S.NRO_SOLICITUD(+)
           And C.COD_PERSONA = ts.Cod_Persona
           And (D.NRO_SOLICITUD = ts.NRO_SOLICITUD
                OR D.Nro_Cuenta = ts.nro_cuenta)
           And A.COD_CAMPANA(+) = S.COD_CAMPANA
           and ts.Fec_Aprobacion = (Select max(ta.fec_aprobacion) from TA_SOL_ADICIONALES ta
                                  where ta.cod_persona = ts.COD_PERSONA
                                    and (ta.NRO_SOLICITUD = ts.NRO_SOLICITUD
                                         OR ta.nro_cuenta = ts.nro_cuenta))
           And NVL(INSTR(FUG_OBT_PARDINAMICO('COD_AFI_SEG_TAR'), D.AFINIDAD),0) = 0

    Union All

   -- Tarjetas Empresariales
   Select C.COD_PERSONA,
               C.NRO_CUENTA,
               C.NRO_TARJETA,
               FUE_OBT_NOM_PERSONA(C.COD_PERSONA) ,
               FUE_OBT_NRO_DOC_PERSONA(C.COD_PERSONA),
               C.COD_ESTADO,
               (Select T.DESCRIPCION
                  From TA_TAR_ESTADOS T
                 Where T.COD_ESTADO = C.COD_ESTADO),
               S.COD_CANAL,
               FUG_OBT_DES_CANAL(S.COD_CANAL),
               NVL(A.COD_CAMPANA, S.COD_CAMPANA) ,
               A.DESCRIPCION ,
               FUG_OBT_COD_USU_OFICIAL(GC.COD_PERSONA),
               FUE_OBT_NOM_USUARIO(FUG_OBT_COD_USU_OFICIAL(GC.COD_PERSONA)) ,
               FUG_OBT_OFI_OFICIAL(GC.COD_PERSONA) OFI_GESTOR,
               FUE_OBT_DES_OFICINA(FUG_OBT_OFI_OFICIAL(GC.COD_PERSONA)) DES_OFI_GESTOR,
               DECODE(D.AFINIDAD, Null, Null,
                      FUG_OBT_DES_AFINIDAD(D.AFINIDAD)),
               DECODE(D.SUB_AFINIDAD, Null, Null,
                      FUE_OBT_DES_REFCODES('SUB_AFINIDAD', D.SUB_AFINIDAD)),
               FUE_OBT_DES_REFCODES('RELACION', T.RELACION),
               (Select Min(H.FECHA)
                  From TA_MOVIMIENTOS_HIS H
                 Where H.NRO_CUENTA = T.NRO_CUENTA) ,
               D.FEC_APERTURA,
               C.FEC_EMISION,
               D.LIN_CREDITO,
               (NVL(D.SAL_FACTURAR, 0) + NVL(D.SAL_FINANCIADO, 0) +
               NVL(D.SAL_FACTURADO, 0)) ,
               S.COD_USU_PROMOTOR,
               FUE_OBT_NOM_USUARIO(S.COD_USU_PROMOTOR) ,
               FUE_OBT_NOM_USUARIO(S.USU_INSERCION) ,
               C.FEC_ACTIVACION,
               FUG_OBT_DES_EST_CTA(D.COD_MODULO, D.COD_MODALIDAD, D.ESTADO),
               FUE_OBT_DES_REFCODES('TIP_EMBOZADO',
                                    (Select NVL(T.TIP_ULT_EMBOZADO, 'X')
                                        From TA_TARJETAS_TMP T
                                       Where T.NRO_CUENTA = C.NRO_CUENTA
                                         And T.NRO_TARJETA = C.NRO_TARJETA
                                         And ROWNUM = 1)),
               S.OBSERVACION
          From TA_TARJETAS     C,
               TA_CTA_TARJETAS D,
               GE_CTA_CLIENTES T,
               CR_CAMPANAS     A,
               TA_SOLICITUDES  S,
               GE_CTA_CLIENTES GC
         Where C.NRO_CUENTA = D.NRO_CUENTA
           And C.NRO_CUENTA = T.NRO_CUENTA
           And C.COD_PERSONA = T.COD_PERSONA
           And D.NRO_SOLICITUD = S.NRO_SOLICITUD(+)
           And A.COD_CAMPANA(+) = S.COD_CAMPANA
           And GC.NRO_CUENTA = C.NRO_CUENTA
           And GC.RELACION = 'P'
           And NVL(INSTR(FUG_OBT_PARDINAMICO('COD_AFI_SEG_TAR'), D.AFINIDAD),0) > 0
;

