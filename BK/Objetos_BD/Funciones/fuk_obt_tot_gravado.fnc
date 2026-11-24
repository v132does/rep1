CREATE OR REPLACE FUNCTION IT.fuk_obt_tot_gravado
   (
      p_cod_proveedor IN NUMBER,
      p_nro_factura   IN VARCHAR2
   ) RETURN NUMBER IS

      v_fec_factura pv_compras.fecha%TYPE;
      v_mto_tot_mes number;

   BEGIN

      SELECT max(fecha)
        INTO v_fec_factura
        FROM pv_compras
       WHERE nro_factura = p_nro_factura
         AND cod_ent_proveedor = p_cod_proveedor
         AND estado IN ('A', 'P');

      SELECT nvl(SUM(pag_gen.fu_con_mon_a_moneda(prov.cod_moneda,pag_gen.fu_obt_mon_local, pdet.val_total)), 0)
        INTO v_mto_tot_mes
        FROM ge_pag_proveedores a, pv_compras prov, pv_compras_det pdet
       WHERE a.estado <> 'A'
         AND prov.nro_factura = a.nro_factura
         AND substr(prov.nom_proveedor,1,50) = substr(a.beneficiario,1,50)
         AND prov.tip_comprobante = a.tip_comprobante
        -- AND (prov.timbrado = a.nro_timbrado OR prov.timbrado IS NULL)
         AND prov.cod_ent_proveedor = p_cod_proveedor
         AND prov.estado IN ('A', 'P')
         AND prov.cod_compra=pdet.cod_compra
         AND nvl(pdet.tip_impuesto, 0) <> 0
         AND to_char(prov.fecha, 'MMYYYY') = to_char(v_fec_factura, 'MMYYYY');
      RETURN v_mto_tot_mes;
   END;
/
