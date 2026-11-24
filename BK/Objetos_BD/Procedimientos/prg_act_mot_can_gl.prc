CREATE OR REPLACE PROCEDURE IT.prg_act_mot_can_gl
(
   p_nro_cta_global    IN ah_tar_debitos.nro_cta_global%TYPE,
   p_nro_tarjeta_deb     IN ah_tar_debitos.nro_tarjeta%TYPE,
   p_cod_motivo     IN ah_tar_debitos.cod_causa%TYPE
) IS

BEGIN
  update ah_tar_debitos s
  set s.cod_causa=p_cod_motivo
  where s.nro_cta_global=p_nro_cta_global
  and s.nro_tarjeta=p_nro_tarjeta_deb;
  commit;
EXCEPTION
   WHEN others THEN
      raise_application_error(-20000, 'No se puede actualizar motivo '||sqlerrm);
       prg_ins_log_programas('IT.prg_act_mot_can_gl',sqlerrm);
END;
/

