CREATE OR REPLACE PROCEDURE IT.PRG_GEN_AGE_ACTIVIDADES
 (P_COD_PERSONA IN CR_AGENDAS.COD_PERSONA%TYPE
 ,P_COD_USU_ENCARGADO IN CR_AGENDAS.COD_USU_ENCARGADO%TYPE
 ,P_COD_ACTIVIDAD IN CR_AGENDAS.COD_ACTIVIDAD%TYPE
 ,P_COD_ESTADO IN CR_AGENDAS.COD_ESTADO%TYPE
 ,P_COD_MOT_ACTIVIDAD IN CR_AGENDAS.COD_MOT_ACTIVIDAD%TYPE
 ,P_FEC_ACTIVIDAD IN CR_AGENDAS.FEC_ACTIVIDAD%TYPE
 ,P_DET_ACTIVIDAD IN CR_AGENDAS.DET_ACTIVIDAD%TYPE
 ,p_nro_referencia in cr_agendas.nro_referencia%type default null)
 IS
begin
insert into cr_agendas
    (cod_agenda, cod_persona,cod_usu_encargado,cod_actividad, cod_estado,
     cod_mot_actividad,fec_actividad,det_actividad, nro_referencia)
values
    (s_cod_agenda.nextval, p_cod_persona, p_cod_usu_encargado,p_cod_actividad,p_cod_estado,
     p_cod_mot_actividad,p_fec_actividad,p_det_actividad, p_nro_referencia);
end;
/

