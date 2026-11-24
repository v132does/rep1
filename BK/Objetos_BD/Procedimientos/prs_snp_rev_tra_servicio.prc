create or replace procedure it.prs_snp_rev_tra_servicio( p_nro_referencia  in ge_snp_transferencias.nro_referencia%type )
is
begin
   update ge_cob_servicios ie
      set ie.ref_numerico1 = null
    where ie.ref_numerico1 = p_nro_referencia;
exception
   when others then
     raise_application_error(-20001, 'Error en PRS_SNP_REV_TRA_SERVICIO para el Nro. referencia ' || p_nro_referencia || ': ' || sqlerrm);
end prs_snp_rev_tra_servicio;
/

