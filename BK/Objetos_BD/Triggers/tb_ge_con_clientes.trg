CREATE OR REPLACE TRIGGER IT.TB_GE_CON_CLIENTES
  before insert or update 
  on it.ge_con_clientes
  for each row
declare
  v_cod_swift it.ge_par_entes.val_parametro%type;
begin
  if inserting then
    select nvl(max(t.nro_contacto), 0) + 1
      into :new.nro_contacto
      from ge_con_clientes t
     where cod_persona = :new.cod_persona;
  end if;
  begin
    select p.val_parametro
      into v_cod_swift
      from ge_par_entes p, ge_entes e
     where parametro = 'COD_SWIFT'
       and p.cod_ente = e.cod_ente
       and e.cod_persona = fug_obt_per_entidad;
  exception
    when others then
      null;
  end;
  
  if :new.cod_ente = v_cod_swift then
    pag_cta.PR_OBT_CUENTA(:new.nro_cta_contacto);
    if nvl(pag_cta.G_COD_ERROR, 0) = 0 then
      if :new.cod_moneda != pag_cta.G_CTAS.COD_MONEDA then
        :new.cod_moneda := pag_cta.G_CTAS.COD_MONEDA;
      end if;
    end if;
  end if;
end TB_GE_CON_CLIENTES;
/

