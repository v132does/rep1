CREATE OR REPLACE PACKAGE IT.pas_tra IS
   --Obtiene el Código Iso de la moneda
   FUNCTION fu_obt_mon_iso(p_cod_moneda IN ba_monedas.cod_moneda%TYPE) RETURN VARCHAR2;   
   FUNCTION fu_obt_ori_fondo
   (
      p_nro_documento IN ba_personas.nro_documento%TYPE
    ) RETURN VARCHAR2; 
   PROCEDURE pr_gen_transferencias;
   FUNCTION fu_obt_mot_autoriza(p_tip_motivo IN lc_transferencias.tip_motivo%TYPE) RETURN VARCHAR2; 
END pas_tra;
/

