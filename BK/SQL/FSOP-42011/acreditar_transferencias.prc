create or replace procedure spi.acreditar_transferencias is
  --Procesar acreditacion automatica, de aquellos que quedaron en REPORTED
  cursor transfer is
    select ref_msg_id
      from SPI.mx_message
     where type = 'pacs.002.001.12'
       and status = 'REPORTED';

begin

  for x in transfer loop

    --Actualiza status
    UPDATE spi.mx_message
       SET status = 'QUEUED', attemps = 0
     WHERE status = 'REPORTED'
       AND ref_msg_id = x.ref_msg_id;
    commit;

  end loop;

end acreditar_transferencias;
/
