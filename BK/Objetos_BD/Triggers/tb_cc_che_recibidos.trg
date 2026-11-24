CREATE OR REPLACE TRIGGER IT."TB_CC_CHE_RECIBIDOS"
 BEFORE DELETE OR INSERT OR UPDATE
 ON CC_CHE_RECIBIDOS
 FOR EACH ROW
declare
v_cod_moneda varchar2(4);
begin
  If inserting then
   --solo x inserción buscar la moneda
    select cod_moneda into v_cod_moneda
      from ge_cuentas
     where nro_cuenta = :new.nro_cuenta;

    If :new.fec_proceso is null then
       :new.fec_proceso :=  pae_cnf.fu_obt_fec_actual(4);
    End if;
    
    -- 19/07/2013 DI PN: Agregado para que los cheques en dolar entren directamente en compensación directa
    
    if v_cod_moneda <> pag_gen.FU_OBT_MON_LOCAL then
       :new.com_directa := 'S';
    end if;   
    

    if :new.monto <> trunc(:new.monto) and v_cod_moneda = pag_gen.FU_OBT_MON_LOCAL then
	     raise_application_error(-20000,'Monto del cheque no debe tener decimales');
	  End if;
  End if;
end;
/

