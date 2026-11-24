create or replace package it.PAG_EQF is
   /* Autor:     Sergio Alejandro Servín Arce
    Propuesta: Paquete para gestión de proceso de datos informconf / infocheck
    Fecha:     16/01/2019
   */
   G_SCK_SERVIDOR varchar2(20) := FUG_OBT_PARDINAMICO('DIP_SCK_CON_ANTECEDENTES');
   G_SCK_PUERTO   number(4) := FUG_OBT_PARDINAMICO('PTO_SCK_CON_ANTECEDENTES');
   G_TIE_ESPERA   number(4) := null;
   G_FEC_ACTUAL   date;
   G_MSG_PROCESO  varchar2(4000);
   G_ERROR exception;
   G_MSG_ERROR      varchar2(4000);
   G_PROCESO        varchar2(500);
   G_NRO_SOLICITUD  number;
   G_NRO_SECUENCIA  number;
   G_PAR_ENVIO      BA_COD_REFERENCIAS.VAL_MINIMO%type;
   G_NOM_SERVICIO   BA_COD_REFERENCIAS.ABREVIATURA%type;
   G_IND_REINTENTO  varchar2(1);
   G_PRO_INDIVIDUAL varchar2(1); --S/N
   G_TIP_PERSONA    varchar2(5);
   G_TIP_SERVICIO   varchar2(2);
   G_TIP_MOT_OPE    varchar2(4) := '|5|3'; --tipo motivo y operación Infocheck 5 = DESCUENTO DE CHEQUES, 3 = LIBRADOR
   G_TIP_DOCUMENTO  varchar2(4);
   G_NRO_DOCUMENTO  BA_PERSONAS.NRO_DOCUMENTO%type;
   G_ACU_ERRORES    number := 0;

   V_REPORTE64      clob;
   V_REPORTEPDF     blob;
   V_NOM_REPORTEPDF varchar2(500);

   G_REP_ARC_SERVIDOR varchar2(100) := FUG_OBT_PARDINAMICO('DIR_SVR_REP_ARCHIVOS');
   G_REP_ARC_PORT     varchar2(100) := '21';
   G_REP_ARC_USER     varchar2(100) := FUG_OBT_PARDINAMICO('USU_FTP_REP_ARCHIVOS');
   G_REP_ARC_PASS     varchar2(100) := FUG_OBT_PARDINAMICO('PAS_FTP_REP_ARCHIVOS');
   G_DIR_DATABASE     varchar2(100) := 'MAIL';
   G_DIR_IFORMES_PDF  varchar2(100) := FUG_OBT_PARDINAMICO('FAD_URL_INF_COMERCIALES');
   --registros de Tablas informconf
   R_GE_EQF_SOLICITUDES          GE_EQF_SOLICITUDES%rowtype;
   R_GE_EQF_FAJ_SCORING          GE_EQF_FAJ_SCORING%rowtype;
   R_GE_EQF_CONVOCATORIA_RES     GE_EQF_CONVOCATORIAS_RES%rowtype;
   R_GE_EQF_DEMANDA_RES          GE_EQF_DEMANDAS_RES%rowtype;
   R_GE_EQF_INHABILITACIONES_RES GE_EQF_INHABILITACIONES_RES%rowtype;
   R_GE_EQF_INHIBICIONES_RES     GE_EQF_INHIBICIONES_RES%rowtype;
   R_GE_EQF_MOR_ACT_ADEFI        GE_EQF_MOR_ACT_ADEFI%rowtype;
   R_GE_EQF_MOR_ACTIVIDAD        GE_EQF_MOR_ACTIVIDADES%rowtype;
   R_GE_EQF_REMATES_RES          GE_EQF_REMATES_RES%rowtype;
   R_GE_EQF_SOL_DETALLE          GE_EQF_SOL_DETALLES%rowtype;
   R_GE_EQF_QUIEBRAS_RES         GE_EQF_QUIEBRAS_RES%rowtype;
   --registros de Tablas tablas infocheck
   R_GE_EQF_CHK_INHABILIT   GE_EQF_CHK_INHABILITACIONES%rowtype;
   R_GE_EQF_CHK_DET_PERSONA GE_EQF_CHK_DET_PERSONAS%rowtype;
   R_GE_EQF_CHK_CONSULTAS   GE_EQF_CHK_CONSULTAS%rowtype;
   R_GE_EQF_CHK_CHE_ANU     GE_EQF_CHK_CHEQUES%rowtype;
   R_GE_EQF_CHK_CHE_REC     GE_EQF_CHK_CHEQUES%rowtype;
   R_GE_EQF_CHK_CHE_RECHIST GE_EQF_CHK_CHEQUES%rowtype;

   function FU_OBT_NOM_REPORTEPDF(P_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type) return varchar2;
   function FU_DEC_BASE64(INBASE64CHAR in out nocopy clob) return clob;

   function FU_ENV_TCP_MSJCLOB(P_SERVIDOR   in varchar2
                              ,P_PUERTO     in number
                              ,P_TIE_ESPERA in number
                              ,P_MENSAJE    in long
                              ,P_RESPUESTA  out clob) return varchar2;

   function FU_BLOB_TO_CLOB(BLOB_IN in blob) return clob;

   function FU_CLOB_TO_BLOB(ACLOB in clob) return blob;

   function FU_CONCAT_BLOB(A in blob
                          ,B in blob) return blob;

   procedure PR_GEN_ARC_PDF(P_NOM_ARCHIVO in varchar2
                           ,P_DIR         in varchar2
                           ,P_BLOB        in blob);
   procedure PR_OBT_PAR_SER_INFORMCONF(P_TIP_SERVICIO in number
                                      ,P_PAR_ENVIO    out varchar2
                                      ,P_NOM_SERVICIO out varchar2);
   procedure PR_OBT_PAR_SER_INFOCHECK(P_TIP_SERVICIO in number
                                     ,P_PAR_ENVIO    out varchar2
                                     ,P_NOM_SERVICIO out varchar2);
   function FU_OBT_TIP_DOCUMENTO(P_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type) return varchar2;
   function FU_OBT_NRO_SOLICITUD(P_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type) return number;
   function FU_VER_REG_ANTECEDENTES(P_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type) return boolean;
   procedure PR_ERR_MENSAJES(P_MENSAJE in varchar2);
   function FU_OBT_DAT_INFORMCONF(P_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type) return varchar2;
   function FU_OBT_DAT_INFOCHECK(P_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type) return varchar2;
   function FU_PRO_DAT_INFORMCONF(P_COD_PERSONA   in BA_PERSONAS.COD_PERSONA%type
                                 ,P_IND_REINTENTO in varchar2
                                 ,P_TIP_SERVICIO  in number) return varchar2;
   function FU_PRO_DAT_INFOCHECK(P_COD_PERSONA   in BA_PERSONAS.COD_PERSONA%type
                                ,P_IND_REINTENTO in varchar2
                                ,P_TIP_SERVICIO  in number) return varchar2;

   procedure PR_ACT_DAT_INFOCHECK(P_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type);
   --procesamiento xml infocheck
   procedure PR_PRO_XML_CHK_DAT_PERSONA(PI_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type
                                       ,P_XMLRESPUESTA in XMLTYPE
                                       ,P_MENSAJE      out varchar2);
   procedure PR_PRO_XML_CHK_DAT_EMPRESA(PI_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type
                                       ,P_XMLRESPUESTA in XMLTYPE
                                       ,P_MENSAJE      out varchar2);
   procedure PR_PRO_XML_CHK_CONSULTBANC(PI_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type
                                       ,P_XMLRESPUESTA in XMLTYPE
                                       ,P_MENSAJE      out varchar2);
   procedure PR_PRO_XML_CHK_CONSULTPUBL(PI_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type
                                       ,P_XMLRESPUESTA in XMLTYPE
                                       ,P_MENSAJE      out varchar2);
   procedure PR_PRO_XML_CHK_CHEQ_REC(PI_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type
                                    ,P_XMLRESPUESTA in XMLTYPE
                                    ,P_MENSAJE      out varchar2);
   procedure PR_PRO_XML_CHK_CHEQ_ANU(PI_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type
                                    ,P_XMLRESPUESTA in XMLTYPE
                                    ,P_MENSAJE      out varchar2);
   procedure PR_PRO_XML_CHK_CHEQ_RECHIST(PI_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type
                                        ,P_XMLRESPUESTA in XMLTYPE
                                        ,P_MENSAJE      out varchar2);
   procedure PR_PRO_XML_CHK_SITUACION(PI_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type
                                     ,P_XMLRESPUESTA in XMLTYPE
                                     ,P_MENSAJE      out varchar2);
   procedure PR_PRO_XML_CHK_INHABIL(PI_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type
                                   ,P_XMLRESPUESTA in XMLTYPE
                                   ,P_MENSAJE      out varchar2);
   procedure PR_PRO_XML_CHK_INHABILHIST(PI_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type
                                       ,P_XMLRESPUESTA in XMLTYPE
                                       ,P_MENSAJE      out varchar2);
   --procesamiento xml--
   procedure PR_PRO_XML_SCORING(PI_COD_PERSONA   in BA_PERSONAS.COD_PERSONA%type
                               ,P_XMLRESPUESTA   in XMLTYPE
                               ,P_PRO_INDIVIDUAL in varchar2
                               ,P_MENSAJE        out varchar2);
   procedure PR_PRO_XML_CONVOCATORIA_RES(PI_COD_PERSONA   in BA_PERSONAS.COD_PERSONA%type
                                        ,P_XMLRESPUESTA   in XMLTYPE
                                        ,P_PRO_INDIVIDUAL in varchar2
                                        ,P_MENSAJE        out varchar2);
   procedure PR_PRO_XML_DEMANDA_RES(PI_COD_PERSONA   in BA_PERSONAS.COD_PERSONA%type
                                   ,P_XMLRESPUESTA   in XMLTYPE
                                   ,P_PRO_INDIVIDUAL in varchar2
                                   ,P_MENSAJE        out varchar2);
   procedure PR_PRO_XML_INHABILITACIO_RES(PI_COD_PERSONA   in BA_PERSONAS.COD_PERSONA%type
                                         ,P_XMLRESPUESTA   in XMLTYPE
                                         ,P_PRO_INDIVIDUAL in varchar2
                                         ,P_MENSAJE        out varchar2);
   procedure PR_PRO_XML_INHIBICIONES_RES(PI_COD_PERSONA   in BA_PERSONAS.COD_PERSONA%type
                                        ,P_XMLRESPUESTA   in XMLTYPE
                                        ,P_PRO_INDIVIDUAL in varchar2
                                        ,P_MENSAJE        out varchar2);
   procedure PR_PRO_XML_MOR_ACT_ADEFI(PI_COD_PERSONA   in BA_PERSONAS.COD_PERSONA%type
                                     ,P_XMLRESPUESTA   in XMLTYPE
                                     ,P_PRO_INDIVIDUAL in varchar2
                                     ,P_MENSAJE        out varchar2);
   procedure PR_PRO_XML_MOR_ACTIVIDAD(PI_COD_PERSONA   in BA_PERSONAS.COD_PERSONA%type
                                     ,P_XMLRESPUESTA   in XMLTYPE
                                     ,P_PRO_INDIVIDUAL in varchar2
                                     ,P_MENSAJE        out varchar2);
   procedure PR_PRO_XML_REMATES_RES(PI_COD_PERSONA   in BA_PERSONAS.COD_PERSONA%type
                                   ,P_XMLRESPUESTA   in XMLTYPE
                                   ,P_PRO_INDIVIDUAL in varchar2
                                   ,P_MENSAJE        out varchar2);
   procedure PR_PRO_XML_SOL_DETALLE(PI_COD_PERSONA   in BA_PERSONAS.COD_PERSONA%type
                                   ,P_XMLRESPUESTA   in XMLTYPE
                                   ,P_PRO_INDIVIDUAL in varchar2
                                   ,P_MENSAJE        out varchar2);
   procedure PR_PRO_XML_QUIEBRAS_RES(PI_COD_PERSONA   in BA_PERSONAS.COD_PERSONA%type
                                    ,P_XMLRESPUESTA   in XMLTYPE
                                    ,P_PRO_INDIVIDUAL in varchar2
                                    ,P_MENSAJE        out varchar2);
   procedure PR_PRO_XML_REPORTE_PDF(PI_COD_PERSONA in BA_PERSONAS.COD_PERSONA%type
                                   ,P_XMLRESPUESTA in XMLTYPE
                                   ,P_MENSAJE      out varchar2);
   procedure PR_INS_SOLICITUD_INF(P_NRO_SOLICITUD in number
                                 ,P_COD_PERSONA   BA_PERSONAS.COD_PERSONA%type);

end;
/

