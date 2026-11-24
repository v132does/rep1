CREATE OR REPLACE PROCEDURE IT.PRC_CON_CHE_DEVUELTOS is
  cursor ches is
    select distinct f.nro_cuenta,
                    c.nro_cheque  nro_cheque,
                    c.tipo,
                    f.cod_persona cod_persona
      from cc_che_dev_firmantes f, cc_che_devueltos c
     where c.fecha >= add_months(pag_cal.fu_obt_fec_actual(4), -12) --Buscar desde un a¿o atras
       and c.fecha >= to_date('21/04/2009','dd/mm/yyyy') --Contar a partir del 21/04/2009, fecha en que entro en vigencia la nueva ley
       and c.nro_cuenta = f.nro_cuenta
       and c.nro_cheque = f.nro_cheque; 
         
begin
  --Cero todos los Totales
  update cc_che_dev_totales set cantidad = 0, fec_ult_regularizacion = null;
  
  for fi in ches loop
    begin
        --Actualizo la tabla de totales
        update cc_che_dev_totales
           set cantidad = nvl(cantidad, 0) + 1
         where cod_persona = fi.cod_persona
           and tipo = fi.tipo;
        if sql%notfound then
          insert into cc_che_dev_totales
            (cod_persona, tipo, cantidad, fec_ult_regularizacion)
          values
            (fi.cod_persona, fi.tipo, 1, null);
        end if;

    exception 
      when others then
        raise_application_error(-20000, 'Cuenta: ' || fi.nro_cuenta || ' Persona: '|| fi.cod_persona || ' cheque: ' || fi.nro_cheque );
    end;
  end loop;
end;
/

