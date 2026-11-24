create or replace force view it.gv_equ_consultas as
select t.usu_insercion||' - '||fue_obt_nom_usuario(t.usu_insercion) usuario,
       t.fecha,
       to_char(t.fec_insercion,'HH24:MI:SS') hora,
       fue_obt_nro_doc_persona(t.cod_persona) nro_documento,
       fue_obt_nom_persona(t.cod_persona) nombre,
       t.cod_persona,
       t.usu_insercion,
       t.fec_insercion,
       t.nom_campo,
       t.res_consulta,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_CANT_ENTIDADES_M_1'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_CANT_ENTIDADES_M_1,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_CANT_ENTIDADES_M_2'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_CANT_ENTIDADES_M_2,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_CANT_ENTIDADES_M_3'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_CANT_ENTIDADES_M_3,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_COMPROMISO_TOTAL_M_1'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_COMPROMISO_TOTAL_M_1,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_COMPROMISO_TOTAL_M_2'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_COMPROMISO_TOTAL_M_2,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_COMPROMISO_TOTAL_M_3'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_COMPROMISO_TOTAL_M_3,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_LIMITE_M_1'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_LIMITE_M_1,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_LIMITE_M_2'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_LIMITE_M_2,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_LIMITE_M_3'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_LIMITE_M_3,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_MAX_DIAS_ATRASO_A_1'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_MAX_DIAS_ATRASO_A_1,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_MAX_DIAS_ATRASO_A_2'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_MAX_DIAS_ATRASO_A_2,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_MAX_DIAS_ATRASO_M_1'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_MAX_DIAS_ATRASO_M_1,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_MAX_DIAS_ATRASO_M_2'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_MAX_DIAS_ATRASO_M_2,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_MAX_DIAS_ATRASO_M_3'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_MAX_DIAS_ATRASO_M_3,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_SALDO_TOTAL_M_1'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_SALDO_TOTAL_M_1,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_SALDO_TOTAL_M_2'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_SALDO_TOTAL_M_2,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_SALDO_TOTAL_M_3'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_SALDO_TOTAL_M_3,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_S_VENCIDO_TOTAL_M_1'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_S_VENCIDO_TOTAL_M_1,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_S_VENCIDO_TOTAL_M_2'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_S_VENCIDO_TOTAL_M_2,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'G_S_VENCIDO_TOTAL_M_3'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) G_S_VENCIDO_TOTAL_M_3,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'P_CLIENTE'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) P_CLIENTE,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'P_ENT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) P_ENT,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'P_EXIGIBLE_PROPIO_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) P_EXIGIBLE_PROPIO_ULT_ACT,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'P_EXIGIBLE_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) P_EXIGIBLE_ULT_ACT,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'P_HIT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) P_HIT,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'P_MAX_DIAS_ATRASO_U3M'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) P_MAX_DIAS_ATRASO_U3M,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'P_MAX_DIAS_ATRASO_U3M_PROPIO'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) P_MAX_DIAS_ATRASO_U3M_PROPIO,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'P_SALDO_PROPIO_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) P_SALDO_PROPIO_ULT_ACT,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'P_SALDO_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) P_SALDO_ULT_ACT,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'P_SALDO_VENCIDO_PROPIO_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) P_SALDO_VENCIDO_PROPIO_ULT_ACT,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'P_SALDO_VENCIDO_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) P_SALDO_VENCIDO_ULT_ACT,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'S_CLIENTE'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) S_CLIENTE,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'S_DEUDA_VENCIDA_PROPIO_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) S_DEUDA_VENCIDA_PROPIO_ULT_ACT,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'S_DEUDA_VENCIDA_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) S_DEUDA_VENCIDA_ULT_ACT,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'S_ENT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) S_ENT,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'S_EXIGIBLE_PROPIO_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) S_EXIGIBLE_PROPIO_ULT_ACT,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'S_EXIGIBLE_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) S_EXIGIBLE_ULT_ACT,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'S_HIT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) S_HIT,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'S_MAX_DIAS_ATRASO_U3M'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) S_MAX_DIAS_ATRASO_U3M,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'S_MAX_DIAS_ATRASO_U3M_PROPIO'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) S_MAX_DIAS_ATRASO_U3M_PROPIO,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'S_SALDO_PROPIO_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) S_SALDO_PROPIO_ULT_ACT,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'S_SALDO_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) S_SALDO_ULT_ACT,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_CLIENTE'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_CLIENTE,
       (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_COMPRAS_MES_PROPIO_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_COMPRAS_MES_PROPIO_ULT_ACT,
           (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_COMPRAS_MES_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_COMPRAS_MES_ULT_ACT,
           (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_ENT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_ENT,
           (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_EXIGIBLE_PROPIO_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_EXIGIBLE_PROPIO_ULT_ACT,
           (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_EXIGIBLE_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_EXIGIBLE_ULT_ACT,
           (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_HIT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_HIT,
           (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_LIMITE_CREDITO_PROP_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_LIMITE_CREDITO_PROP_ULT_ACT,
           (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_LIMITE_CREDITO_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_LIMITE_CREDITO_ULT_ACT,
           (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_MAX_DIAS_ATRASO_U3M'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_MAX_DIAS_ATRASO_U3M,
           (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_MAX_DIAS_ATRASO_U3M_PROPIO'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_MAX_DIAS_ATRASO_U3M_PROPIO,
           (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_MAX_LIM_CRED'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_MAX_LIM_CRED,
           (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_MAX_LIM_CRED_PROPIO'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_MAX_LIM_CRED_PROPIO,
           (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_SALDO_CUOTAS_PROP_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_SALDO_CUOTAS_PROP_ULT_ACT,
           (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_SALDO_CUOTAS_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_SALDO_CUOTAS_ULT_ACT,
           (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_SALDO_TOTAL_PROP_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_SALDO_TOTAL_PROP_ULT_ACT,
           (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_SALDO_TOTAL_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_SALDO_TOTAL_ULT_ACT,
           (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_SALDO_VENCIDO_PROP_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_SALDO_VENCIDO_PROP_ULT_ACT,
           (select d.res_consulta
          from ge_equ_consultas_det d
         where d.nom_campo = 'TC_SALDO_VENCIDO_ULT_ACT'
           and d.fecha = t.fecha
           and d.cod_persona = t.cod_persona ) TC_SALDO_VENCIDO_ULT_ACT
from GE_EQU_CONSULTAS_DET t
union all
select T.usu_insercion||' - '||fue_obt_nom_usuario(T.usu_insercion) usuario,
       T.fecha,
       T.hora,
       fue_obt_nro_doc_persona(T.cod_persona) nro_documento,
       fue_obt_nom_persona(T.cod_persona) nombre,
       t.cod_persona,
       t.usu_insercion,
       t.fec_insercion,
       t.nom_campo,
       t.res_consulta,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_CANT_ENTIDADES_M_1'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_CANT_ENTIDADES_M_1,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_CANT_ENTIDADES_M_2'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_CANT_ENTIDADES_M_2,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_CANT_ENTIDADES_M_3'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_CANT_ENTIDADES_M_3,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_COMPROMISO_TOTAL_M_1'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_COMPROMISO_TOTAL_M_1,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_COMPROMISO_TOTAL_M_2'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_COMPROMISO_TOTAL_M_2,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_COMPROMISO_TOTAL_M_3'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_COMPROMISO_TOTAL_M_3,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_LIMITE_M_1'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_LIMITE_M_1,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_LIMITE_M_2'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_LIMITE_M_2,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_LIMITE_M_3'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_LIMITE_M_3,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_MAX_DIAS_ATRASO_A_1'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_MAX_DIAS_ATRASO_A_1,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_MAX_DIAS_ATRASO_A_2'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_MAX_DIAS_ATRASO_A_2,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_MAX_DIAS_ATRASO_M_1'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_MAX_DIAS_ATRASO_M_1,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_MAX_DIAS_ATRASO_M_2'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_MAX_DIAS_ATRASO_M_2,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_MAX_DIAS_ATRASO_M_3'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_MAX_DIAS_ATRASO_M_3,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_SALDO_TOTAL_M_1'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_SALDO_TOTAL_M_1,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_SALDO_TOTAL_M_2'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_SALDO_TOTAL_M_2,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_SALDO_TOTAL_M_3'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_SALDO_TOTAL_M_3,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_S_VENCIDO_TOTAL_M_1'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_S_VENCIDO_TOTAL_M_1,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_S_VENCIDO_TOTAL_M_2'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_S_VENCIDO_TOTAL_M_2,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'G_S_VENCIDO_TOTAL_M_3'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) G_S_VENCIDO_TOTAL_M_3,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'P_CLIENTE'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) P_CLIENTE,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'P_ENT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) P_ENT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'P_EXIGIBLE_PROPIO_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) P_EXIGIBLE_PROPIO_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'P_EXIGIBLE_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) P_EXIGIBLE_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'P_HIT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) P_HIT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'P_MAX_DIAS_ATRASO_U3M'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) P_MAX_DIAS_ATRASO_U3M,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'P_MAX_DIAS_ATRASO_U3M_PROPIO'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) P_MAX_DIAS_ATRASO_U3M_PROPIO,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'P_SALDO_PROPIO_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) P_SALDO_PROPIO_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'P_SALDO_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) P_SALDO_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'P_SALDO_VENCIDO_PROPIO_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) P_SALDO_VENCIDO_PROPIO_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'P_SALDO_VENCIDO_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) P_SALDO_VENCIDO_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'S_CLIENTE'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) S_CLIENTE,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'S_DEUDA_VENCIDA_PROPIO_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) S_DEUDA_VENCIDA_PROPIO_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'S_DEUDA_VENCIDA_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) S_DEUDA_VENCIDA_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'S_ENT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) S_ENT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'S_EXIGIBLE_PROPIO_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) S_EXIGIBLE_PROPIO_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'S_EXIGIBLE_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) S_EXIGIBLE_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'S_HIT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) S_HIT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'S_MAX_DIAS_ATRASO_U3M'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) S_MAX_DIAS_ATRASO_U3M,
           (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'S_MAX_DIAS_ATRASO_U3M_PROPIO'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora) S_MAX_DIAS_ATRASO_U3M_PROPIO,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'S_SALDO_PROPIO_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) S_SALDO_PROPIO_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'S_SALDO_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) S_SALDO_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_CLIENTE'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_CLIENTE,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_COMPRAS_MES_PROPIO_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_COMPRAS_MES_PROPIO_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_COMPRAS_MES_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_COMPRAS_MES_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_ENT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_ENT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_EXIGIBLE_PROPIO_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_EXIGIBLE_PROPIO_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_EXIGIBLE_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_EXIGIBLE_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_HIT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_HIT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_LIMITE_CREDITO_PROP_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_LIMITE_CREDITO_PROP_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_LIMITE_CREDITO_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_LIMITE_CREDITO_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_MAX_DIAS_ATRASO_U3M'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_MAX_DIAS_ATRASO_U3M,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_MAX_DIAS_ATRASO_U3M_PROPIO'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_MAX_DIAS_ATRASO_U3M_PROPIO,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_MAX_LIM_CRED'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_MAX_LIM_CRED,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_MAX_LIM_CRED_PROPIO'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_MAX_LIM_CRED_PROPIO,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_SALDO_CUOTAS_PROP_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_SALDO_CUOTAS_PROP_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_SALDO_CUOTAS_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_SALDO_CUOTAS_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_SALDO_TOTAL_PROP_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_SALDO_TOTAL_PROP_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_SALDO_TOTAL_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_SALDO_TOTAL_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_SALDO_VENCIDO_PROP_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_SALDO_VENCIDO_PROP_ULT_ACT,
       (select h.res_consulta
          from ge_equ_consultas_det_his h
         where h.nom_campo = 'TC_SALDO_VENCIDO_ULT_ACT'
           and h.fecha = t.fecha
           and h.cod_persona = t.cod_persona
           and h.hora = t.hora ) TC_SALDO_VENCIDO_ULT_ACT
from GE_EQU_CONSULTAS_DET_his T;

