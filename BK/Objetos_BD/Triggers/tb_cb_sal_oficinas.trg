CREATE OR REPLACE TRIGGER IT.TB_CB_SAL_OFICINAS
  BEFORE INSERT  ON cb_sal_oficinas
  FOR EACH ROW
declare
  v_cantidad number(3);
BEGIN

  if inserting  then
       begin
        Select  nvl(count(*),0)
           into v_cantidad
             from cb_rubros t
                where t.cod_rubro = :new.cod_rubro;
       exception
         when no_data_found then
              v_cantidad:=0;
         when others then
              v_cantidad:=0;
       end;
    if nvl(v_cantidad, 0) =  0  then
      raise_application_error(-20000,'El rubro contable no existe');
    end if;

  end if;

end;
/

