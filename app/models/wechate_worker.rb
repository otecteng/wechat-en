class WechateWorker

  def self.create_worker(worker)
    worker.new
  end

  def text_callback(msg_id,text)
  end

  def image_callback(msg_id,args)
  end

  def location_callback(msg_id,args)
  end

  def voice_callback(msg_id,args)
  end

  def click_callback(msg_id,args)
  end

  def scancode_callback(msg_id,args)
  end

end