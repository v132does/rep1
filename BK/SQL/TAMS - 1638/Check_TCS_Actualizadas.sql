-- Cantidad de TCs a actualizadas:  

  SELECT count(*)
    FROM  ah_tar_debitos s 
    WHERE s.fec_modificacion>=trunc(sysdate)
      and s.usu_modificacion=user;


  SELECT *
    FROM  ah_tar_debitos s 
    WHERE s.fec_modificacion>=trunc(sysdate)
      and s.usu_modificacion=user;

  SELECT count(*)
    FROM  ah_tar_debitos s 
    WHERE s.id is null;

  SELECT count(*)
    FROM  ta_tarjetas s 
    WHERE s.id is null;

  select s.* 
  from ge_log_errores s 
  where s.cod_programa in ('UPDATE_TD_UUID_BANCARD')
  and s.fec_insercion>=trunc(sysdate)
  order by s.fec_insercion desc;