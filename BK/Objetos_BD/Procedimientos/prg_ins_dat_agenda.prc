CREATE OR REPLACE PROCEDURE IT.prg_ins_dat_agenda IS
  
  v_cod_agenda cr_agendas.cod_agenda%type;
  CURSOR cr_age IS
    select a.fecha,a.cliente,a.ges_realizada_desc,
           'Usuario: '||FUE_OBT_DES_REFCODES('USU_GESTION_COBRANZA',a.usu_gestion)||'.- Nota: '||a.ges_realizada_nota||'.- Fecha a pagar: '||a.ges_realizada_pp_fecpago||'.- Monto a pagar: '||a.ges_realiada_pp_importe respuesta
      from cr_agendas_tmp a;
      
BEGIN
  
  FOR a in cr_age LOOP
    select s_cod_agenda.nextval into v_cod_agenda from dual; --para el codigo de agenda
      
      INSERT INTO cr_agendas 
         (cod_agenda,cod_persona,cod_usu_encargado,cod_actividad,cod_estado,cod_mot_actividad,fec_actividad,det_actividad,
          fec_realizacion,det_respuesta,automatico)
      VALUES
         (v_cod_agenda,a.cliente,user,4,3,4,a.fecha,a.ges_realizada_desc,a.fecha,a.respuesta,'S');
		 
  END LOOP;
  
EXCEPTION
   WHEN OTHERS THEN
      raise_application_error(-20000, 'Error en prg_ins_dat_agenda. ' || SQLERRM);
END prg_ins_dat_agenda;
/

