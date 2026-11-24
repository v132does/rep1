create or replace function it.fuj_obt_num_documento
 (p_nro_caja in number default null
 ,p_cod_oficina in number default null
 ,p_cod_moneda in varchar2 default null
 ,p_fecha in date default null
 ,p_hora in varchar2 default null
 ,p_cod_transaccion in number default null)
 return number
 is
v_nro_document number ;
begin
  select c.nro_documento
     into v_nro_document
     from cj_con_documentos c
    where c.nro_caja = p_nro_caja
      and c.cod_oficina = p_cod_oficina
      and c.cod_moneda = p_cod_moneda
      and c.fecha = p_fecha
      and c.cod_transaccion = p_cod_transaccion
      and c.fec_insercion = (select max(fec_insercion)
                                from cj_con_documentos
                               where nro_caja = c.nro_caja
                                 and cod_oficina = c.cod_oficina
                                 and cod_moneda = c.cod_moneda
                                 and fecha = c.fecha
                                 and cod_transaccion = c.cod_transaccion) ;
    return v_nro_document;
exception
   when no_data_found then
        raise_application_error(-20000, 'No existe Nro. de Documento');
   when others then
           raise_application_error(-20000,'Error en. '||sqlerrm);
end;
/

