CREATE OR REPLACE FUNCTION IT.fus_obt_nom_sub_participante
 ( p_cod_swift_padre in varchar2 , p_cod_swift_sub in varchar2 ) return varchar2
 IS
 
 --DA-6948

   /*
   || Obtiene el nombre del subparticipante de una transf.Patrocinador
   */

   v_nom_subParticipante ge_snp_patrocinador_det.subparticipante%type;
BEGIN

    select d.subparticipante
      into v_nom_subParticipante
      from ge_snp_patrocinador_cab s, ge_snp_patrocinador_det d
     where s.cod_swift = d.cod_swift_padre
       and d.estado = 'S'
       and d.cod_swift_padre = p_cod_swift_padre
       and d.cod_swift_sub = p_cod_swift_sub;

     return v_nom_subParticipante;
     
EXCEPTION
  when no_data_found then
     return NULL;
  when others then
     return NULL;
END fus_obt_nom_sub_participante;
/

