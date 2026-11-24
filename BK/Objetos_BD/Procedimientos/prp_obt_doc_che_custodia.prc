CREATE OR REPLACE PROCEDURE IT.prp_obt_doc_che_custodia(p_cta_libradora     IN ge_che_custodias.cta_libradora%TYPE,
                                                     p_cod_banco         IN ge_che_custodias.cod_banco%TYPE,
                                                     p_nro_cheque        IN ge_che_custodias.nro_cheque%TYPE,
                                                     p_cod_tip_documento OUT pr_rel_chq_lib.cod_tip_documento%TYPE,
                                                     p_nro_documento     OUT pr_rel_chq_lib.nro_documento%TYPE) IS
BEGIN
   select p.cod_tip_documento, p.nro_documento
     into p_cod_tip_documento, p_nro_documento
     from pr_rel_chq_lib p
    where p.cta_libradora = p_cta_libradora
      and p.cod_banco = p_cod_banco
      and p.nro_cheque = p_nro_cheque
      and rownum = 1;
EXCEPTION
   WHEN OTHERS THEN
      NULL;
END;
/

