declare

  v_tip_producto number;

begin

  begin
    pre_ini_aplicacion;
    pae_cnf.g_cod_modulo := 1;
  end;
  
  select t.tip_producto
    into v_tip_producto
    from ge_mai_onb_templates t
   where descripcion = 'Envio de Oferta Che Roga generada';

  insert into ba_cod_referencias
    (dominio,
     significado,
     fec_insercion,
     usu_insercion,
     usu_modificacion,
     fec_modificacion,
     val_minimo,
     val_maximo,
     abreviatura,
     activo)
  values
    ('TIP_MAI_PRODUCTO',
     'Envio de Oferta Che ROGA (Oficial de Cuentas)',
     sysdate,
     user,
     user,
     sysdate,
     'ENVIOROGA',
     v_tip_producto,
     'CHE ROGA ENVIADO OFICIAL',
     'S');

  commit;
end;
