create or replace function it.fup_obt_libr_cheque_cus(p_cta_libradora in ge_che_custodias.cta_libradora%type,
                                                   p_cod_banco     in ge_che_custodias.cod_banco%type,
                                                   p_nro_cheque    in ge_che_custodias.nro_cheque%type)
  return varchar2 is
  result pr_chq_libradores.nom_completo%type;
begin
  select upper(l.nom_completo)
    into result
    from pr_rel_chq_lib p, pr_chq_libradores l
   where p.cta_libradora = p_cta_libradora
     and p.cod_banco = p_cod_banco
     and p.nro_cheque = p_nro_cheque
     and p.nro_documento = l.nro_documento
     and rownum < 2;
  return result;
exception
  when others then
    return null;
end;
/

