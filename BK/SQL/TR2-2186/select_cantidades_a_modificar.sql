--Cantidad de TD's a actualizar:
select count(*)cantidad_TD
    from ah_tar_debitos s 
    where s.cod_ent_procesadora='1175' 
      and s.id is null 
      and s.tar_activa='S';
--Cantidad de TC's a actualizar:      
select count(*)cantidad_TC
    from ta_tarjetas s 
    where s.id is null 
      and s.vigente='S'
      and exists (SELECT 1
                    FROM ta_cta_tarjetas a, (select distinct b.afinidad,
                                             b.cod_modalidad,
                                             b.cod_ent_procesadora
                                             from ta_tipos b
                                             where b.cod_ent_procesadora='1175')b
                   WHERE a.cod_modalidad = b.cod_modalidad
                     AND a.afinidad = b.afinidad
                     AND a.nro_cuenta=s.nro_cuenta);
