CREATE OR REPLACE TYPE IT."TYP_OBTINFPAGO"                                          AS OBJECT
(nro_referencia                                 VARCHAR2(33),
 nro_ref_externa                                VARCHAR2(33),
 cod_msj_mx                                     VARCHAR2(8),
 fecha                                          DATE,
 hora                                           VARCHAR2(8),
 cod_swi_solicitante                            VARCHAR2(20),
 tip_par_solicitante                            VARCHAR2(2),
 par_rec_consulta                               VARCHAR2(20),
 inf_suplementaria                              VARCHAR2(200),
 nro_ref_msj_original                           VARCHAR2(33),
 tip_msj_original                               VARCHAR2(20),
 fec_ins_msj_original                           DATE,
 hor_ins_msj_original                           VARCHAR2(8),
 cod_swi_sol_original                           VARCHAR2(20),
 tip_par_original                               VARCHAR2(2),
 fec_valor_msj_original                         DATE,
 cod_tip_rechazo                                VARCHAR2(20),
 mot_tip_rechazo                                VARCHAR2(240));
/

