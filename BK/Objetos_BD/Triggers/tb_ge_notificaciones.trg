CREATE OR REPLACE TRIGGER IT.tb_ge_notificaciones
 before insert or update on ge_notificaciones
 for each row
declare
  v_sender     varchar2(100);
  v_dominio    varchar2(100) := fug_obt_pardinamico('DOM_SENDER');
  v_dom_sender varchar2(100);
begin
  if inserting or updating then
    if :new.env_por != nvl(:old.env_por,'x') then
      v_sender := trim(:new.env_por);
      v_dom_sender := trim(substr(v_sender,instr(v_sender,'@')+1,length(v_sender)));
      if v_dom_sender != v_dominio then
        v_sender := substr(v_sender,1, instr(v_sender,'@'))||v_dominio;
        :new.env_por := v_sender;
      end if;
    end if;
  end if;
end;
/

