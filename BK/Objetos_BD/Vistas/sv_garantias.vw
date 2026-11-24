create or replace force view it.sv_garantias as
Select c.cod_oficina,
       c.cod_moneda,
       c.nro_garantia,
       c.cod_garantia,
       pas_cri.fu_obt_ref_gar_bco_central(a.cod_garantia)ref_gar_bcp,
       c.rango,
       c.fec_inicio,
       c.fec_confirmacion,
       c.fec_vencimiento,
       decode (c.estado,'N', 0, nvl(c.valor,0)) valor,
       nvl(c.cod_mon_tasacion, c.cod_moneda) cod_mon_tasacion,
       decode (c.tipo,'A','N','C','S') tipo,
       c.perfeccionada,
       c.cod_persona,
       c.estado,
       a.nom_tab_anexa,
       c.fec_modificacion
  from pr_garantias c, pr_gar_tipos a
 where c.cod_garantia = a.cod_garantia
   and a.computable = 'S'
   and ((pas_cri.fu_obt_cod_entidad = 2037 AND c.usu_insercion <> 'MIGRA') or
         pas_cri.fu_obt_cod_entidad <> 2037);

