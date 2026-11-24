CREATE OR REPLACE PROCEDURE IT.prg_obt_dat_par_beneficiario
(  p_cod_swi_participante           IN  ge_snp_transferencias.cod_swi_pte_solicitante%type,
   p_cuentaCredito                  IN  ge_snp_transferencias.nro_cta_beneficiario%type,
   p_ind_cooperativa                OUT VARCHAR2,
   p_ind_habilitada                 OUT VARCHAR2,
   p_cta_interna_sub                OUT ge_snp_patrocinador_det.cta_interna_sub%type,
   p_cod_swift_padre                OUT ge_snp_patrocinador_det.cod_swift_padre%type)
IS




   v_ind_coop            varchar2(1):='N';
   v_existe              number(10);
   v_cta_res             varchar2(1):='S';
   v_cta_sub             ge_snp_patrocinador_det.cta_interna_sub%type:=NULL;
   v_cod_swift           ge_snp_transferencias.cod_swi_pte_solicitante%type:=NULL;
   v_cod_swift_padre     ge_snp_patrocinador_det.cod_swift_padre%type:=NULL;
   v_cod_swift_sub       ge_snp_patrocinador_det.cod_swift_sub%type:=NULL;


BEGIN

      -- Devuelve los datos relacionado al swift
      --1.control de si el swift corresponde a patrocinadores

        begin
        select 'S',cod_swift_sub, cta_interna_sub, cod_swift_padre
          into v_ind_coop,v_cod_swift_sub, v_cta_sub, v_cod_swift_padre
          from ge_snp_patrocinador_det
         where cod_swift_sub = p_cod_swi_participante
           and estado = 'S';
        exception 
          when no_data_found then 
          v_ind_coop := 'N'; 
        end; 
        if v_cod_swift_padre is null and v_ind_coop='N' then
            v_cod_swift:= p_cod_swi_participante;
         end if;
        --2 Control si la cuenta beneficiaria no está inhabilitada para recibir transferencias
         select count(*)
        into v_existe
        from ge_snp_cta_restringidas re
        where instr(p_cuentaCredito,re.nro_cuenta)>0
        and re.cod_swi_entidad=(case v_ind_coop
                                 when 'S' then
                                     v_cod_swift_sub
                                 else
                                     v_cod_swift
                                 end)
       and re.estado='A';
       
       if v_existe>0 then
          v_cta_res:='N';
       end if;
      --devuelve los valores respectivos.
      p_ind_cooperativa := v_ind_coop; 
      p_cta_interna_sub:= v_cta_sub;
      p_cod_swift_padre:=v_cod_swift_padre;
      p_ind_habilitada:=v_cta_res;
 
  EXCEPTION 
    WHEN others then 
      IF sqlcode < -20000 THEN 
        raise; ELSE raise_application_error(-20002, 'Error en prg_obt_dat_par_beneficiario' || '-' || sqlerrm); 
        
        END IF; 
END;
/
