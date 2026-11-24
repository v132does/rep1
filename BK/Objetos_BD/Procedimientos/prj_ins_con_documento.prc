create or replace procedure it.PRJ_INS_CON_DOCUMENTO
 (p_nro_documento in ge_movimientos.nro_documento%type
 ,p_nro_caja in number := null
 ,p_cod_oficina in number := null
 ,p_cod_moneda in varchar2 := null
 ,p_fecha in date := null
 ,p_hora in varchar2 := null
 ,p_cod_transaccion in number := null)
 is
begin
   insert into cj_con_documentos(nro_documento,
                                 nro_caja,
                                 cod_oficina,
                                 cod_moneda,
                                 fecha,
                                 cod_usuario,
                                 hora,
                                 cod_transaccion)
                          values(p_nro_documento,
                                 p_nro_caja,
                                 p_cod_oficina,
                                 p_cod_moneda,
                                 p_fecha,
                                 user,
                                 p_hora,
                                 p_cod_transaccion) ;

exception
  when others then
      raise_application_error(-20001, 'no pudo insertar. '||sqlerrm);
end;
/

