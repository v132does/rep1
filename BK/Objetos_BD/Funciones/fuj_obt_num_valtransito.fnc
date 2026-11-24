create or replace function it.fuj_obt_num_valtransito return number
 is
v_nro_transito number ;
v_numero       number := 1 ;
v_existe       varchar2(1) ;
begin
  while v_numero >= 1 loop
      SELECT S_NRO_TRANSITO.nextval
        INTO v_nro_transito
        FROM dual;
      begin
             select 'S'
               into v_existe
               from cj_val_transito ct
              where ct.nro_documento = v_nro_transito ;
      exception
        when no_data_found then
          v_existe := 'N' ;
          v_numero := 0 ;
        when others then
           raise_application_error(-20000,'Error en. '||sqlerrm);
      end ;
 end loop ;
    return v_nro_transito ;
exception
   when no_data_found then
        raise_application_error(-20000, 'No existe Nro. de Documento');
   when others then
           raise_application_error(-20000,' Error en. '||sqlerrm);
end;
/

