CREATE OR REPLACE PROCEDURE IT.PRF_INS_BIEN
 (r_bien IN AF_BIENES%ROWTYPE,
  p_tip_venta IN PV_COMPRAS.TIP_VENTA%TYPE
 )
 IS
 v_fec_vto_depreciacion af_bienes.fec_vto_depreciacion%type;
 v_anos_deprecia        af_articulos.ano_depreciacion%type;
 v_anos_dep_Acelerado   af_articulos.ano_depreciacion%type;
 v_ind_depreciacion     af_articulos.ind_depreciacion%type;
 v_estado               af_bienes.estado%type;
 v_cont                 number(3);
 v_val_dep_mensual      af_bienes.val_compra%type;
 v_mes_vid_util         number(6);
 v_por_val_residual     af_bienes.por_val_res_bien%type;
 v_por_val_depreciable  af_bienes.por_val_dep_bien%type;
 
BEGIN
   ---
   select a.ind_depreciacion, a.ano_depreciacion, a.ano_dep_acelerado,
          nvl(a.por_val_residual,0), nvl(a.por_val_depreciable,100)
   into   v_ind_depreciacion, v_anos_deprecia, v_anos_dep_Acelerado,
          v_por_val_residual, v_por_val_depreciable
   from   af_articulos a
   where  a.cod_articulo = r_bien.cod_articulo;
   ---
   if v_ind_depreciacion = 'S' then

        if fug_obt_tip_implementacion in (1,2) and v_anos_deprecia > v_anos_dep_Acelerado then
            v_fec_vto_depreciacion := ADD_MONTHS(r_bien.fec_compra, 12 * v_anos_dep_acelerado);
        elsif fug_obt_tip_implementacion in (1,2) and v_anos_deprecia = v_anos_dep_Acelerado then
            v_fec_vto_depreciacion := ADD_MONTHS(r_bien.fec_compra, 12 * v_anos_deprecia);    
        else
          if v_fec_vto_depreciacion is not null then 
             v_fec_vto_depreciacion := to_date('31/12/'||to_char(v_fec_vto_depreciacion,'YYYY'),'dd/mm/yyyy');
          end if; 
        end if;
        -----
        v_mes_vid_util := 
        (to_number(to_char(v_fec_vto_depreciacion,'yyyy'))-
         to_number(to_char(r_bien.fec_compra,'yyyy')))*12;
        v_val_dep_mensual := round((r_bien.val_compra*(v_por_val_depreciable/100))/v_mes_vid_util);
        -----
   else
      v_fec_vto_depreciacion := null;
      v_val_dep_mensual := 0;
   end if;
   ---
   if nvl(p_tip_venta,'CO') in ('CR','CO') then
       v_estado := 'A';
   end if;   
   ----
   insert into af_bienes(
   cod_bien,cod_articulo,descripcion,
   cod_oficina,cod_area,val_compra,cod_moneda,
   fec_compra,cod_ent_proveedor,nro_factura,tipo,
   fec_vto_depreciacion, estado, cod_compra,
   dep_mensual,por_val_res_bien,por_val_dep_bien,
   rev_actual, dep_actual, dep_acumulada, val_neto)
   values(
   r_bien.cod_bien,r_bien.cod_articulo,r_bien.descripcion,
   r_bien.cod_oficina,r_bien.cod_area,r_bien.val_compra,r_bien.cod_moneda,
   r_bien.fec_compra,r_bien.cod_ent_proveedor,r_bien.nro_factura,r_bien.tipo,
   v_fec_vto_depreciacion,v_estado, r_bien.cod_compra,
   v_val_dep_mensual,v_por_val_residual,v_por_val_depreciable,
   r_bien.val_compra, 0, 0, r_bien.val_compra);
   ---
exception
   when others then
      raise_application_error(-20000,'Ins.Bien '||r_bien.descripcion||'-'||v_fec_vto_depreciacion ||'-'||sqlerrm);
END;
/

