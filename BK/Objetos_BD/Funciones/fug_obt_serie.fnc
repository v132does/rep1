create or replace function it.FUG_OBT_SERIE(p_tip_comprobante in cb_par_comprobantes.tipo%type,
                                            p_cod_oficina in cb_par_comprobantes.cod_oficina%type,
                                            p_nro_timbrado in cb_par_comprobantes.nro_timbrado%type) return varchar2 IS
--Proyecto: Facturación Electrónica
--Función que devuelve la Serie del timbrado correspondiente al circuito de Facturación Electrónica 
--Adaptada a la definición de la pagina 59 del Manual Técinco e-Kuatia v.150 del 10_09_2019
--por mmelgarejo 09/09/2022 

v_serie cb_par_comprobantes.serie%TYPE;
v_tip_facturacion cb_par_comprobantes.tip_facturacion%TYPE;
BEGIN
  select a.serie,
         nvl(a.tip_facturacion,'N')
    into v_serie,
         v_tip_facturacion
    from cb_par_comprobantes a
   where a.tipo = p_tip_comprobante
     and a.cod_oficina = p_cod_oficina
     and a.nro_timbrado = p_nro_timbrado;
  
  if v_tip_facturacion = 'N' then
    v_serie := null;
  end if;
  
  return v_serie;
  
exception
  when others then
    return null;
END;
/

